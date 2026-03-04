--
-- PostgreSQL database dump
--

\restrict ilI9sqsVHba9I2V5VI9bxAjyx5LthA66upiA3xpsRwBDkvv6yNDD99tiacUoPwy

-- Dumped from database version 18.0
-- Dumped by pg_dump version 18.0

-- Started on 2026-03-04 10:47:38

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 4 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 5093 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 240 (class 1255 OID 24880)
-- Name: generate_valid_card_number(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_valid_card_number(brand character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix VARCHAR;
    card_base VARCHAR;
    card_num VARCHAR;
    check_digit INTEGER;
    exists_check INTEGER;
    max_attempts INTEGER := 1000;
    attempt INTEGER := 0;
BEGIN
    -- Префиксы платёжных систем
    prefix := CASE brand
        WHEN 'visa' THEN '4'
        WHEN 'mastercard' THEN '5'
        WHEN 'mir' THEN '2'
        WHEN 'unionpay' THEN '6'
        ELSE '4'
    END;
    
    -- Цикл генерации с проверкой уникальности
    LOOP
        -- Генерируем 14 случайных цифр (15-я будет контрольной)
        card_base := prefix || LPAD(FLOOR(RANDOM() * 100000000000000)::TEXT, 14, '0');
        
        -- Вычисляем контрольную цифру по алгоритму Луна
        check_digit := (10 - luhn_checksum(card_base || '0')) % 10;
        
        -- Формируем полный номер карты
        card_num := card_base || check_digit::TEXT;
        
        -- Проверяем уникальность
        SELECT COUNT(*) INTO exists_check 
        FROM cards 
        WHERE card_number = card_num;
        
        -- Если номер уникален - выходим
        IF exists_check = 0 THEN
            EXIT;
        END IF;
        
        attempt := attempt + 1;
        
        IF attempt >= max_attempts THEN
            RAISE EXCEPTION 'Не удалось сгенерировать уникальный номер карты после % попыток', max_attempts;
        END IF;
    END LOOP;
    
    -- Форматируем номер: 0000 0000 0000 0000
    card_num := SUBSTRING(card_num FROM 1 FOR 4) || ' ' ||
                SUBSTRING(card_num FROM 5 FOR 4) || ' ' ||
                SUBSTRING(card_num FROM 9 FOR 4) || ' ' ||
                SUBSTRING(card_num FROM 13 FOR 4);
    
    RETURN card_num;
END;
$$;


ALTER FUNCTION public.generate_valid_card_number(brand character varying) OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 24881)
-- Name: is_valid_card_number(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_valid_card_number(card_num character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
DECLARE
    clean_num VARCHAR;
BEGIN
    -- Убираем пробелы
    clean_num := REPLACE(card_num, ' ', '');
    
    -- Проверяем что только цифры и длина 16
    IF clean_num !~ '^\d{16}$' THEN
        RETURN FALSE;
    END IF;
    
    -- Проверяем по алгоритму Луна
    RETURN luhn_checksum(clean_num) = 0;
END;
$_$;


ALTER FUNCTION public.is_valid_card_number(card_num character varying) OWNER TO postgres;

--
-- TOC entry 228 (class 1255 OID 24879)
-- Name: luhn_checksum(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.luhn_checksum(card_num character varying) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    digit INTEGER;
    sum INTEGER := 0;
    double_digit INTEGER;
    i INTEGER;
    len INTEGER;
BEGIN
    len := LENGTH(card_num);
    
    -- Проходим по цифрам справа налево
    FOR i IN REVERSE len..1 LOOP
        digit := SUBSTRING(card_num FROM i FOR 1)::INTEGER;
        
        -- Удваиваем каждую вторую цифру справа
        IF (len - i) % 2 = 1 THEN
            double_digit := digit * 2;
            -- Если результат > 9, вычитаем 9
            IF double_digit > 9 THEN
                double_digit := double_digit - 9;
            END IF;
            sum := sum + double_digit;
        ELSE
            sum := sum + digit;
        END IF;
    END LOOP;
    
    RETURN sum % 10;
END;
$$;


ALTER FUNCTION public.luhn_checksum(card_num character varying) OWNER TO postgres;

--
-- TOC entry 227 (class 1255 OID 24877)
-- Name: update_cards_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_cards_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_cards_updated_at() OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 24884)
-- Name: validate_card_number_trigger(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_card_number_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Убираем пробелы для проверки
    IF NOT is_valid_card_number(NEW.card_number) THEN
        RAISE EXCEPTION 'Невалидный номер карты: %', NEW.card_number;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_card_number_trigger() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 222 (class 1259 OID 24824)
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts (
    id integer NOT NULL,
    user_id integer,
    account_number character varying(20) NOT NULL,
    balance numeric(15,2) DEFAULT 0.00,
    account_type character varying(50) DEFAULT 'debit'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.accounts OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 24823)
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.accounts_id_seq OWNER TO postgres;

--
-- TOC entry 5094 (class 0 OID 0)
-- Dependencies: 221
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- TOC entry 224 (class 1259 OID 24843)
-- Name: cards; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cards (
    id integer NOT NULL,
    account_id integer,
    card_number character varying(19) NOT NULL,
    card_holder_name character varying(100) NOT NULL,
    expiry_date date NOT NULL,
    cvv_hash character varying(255),
    card_type character varying(20) DEFAULT 'debit'::character varying,
    card_brand character varying(20) DEFAULT 'visa'::character varying,
    is_active boolean DEFAULT true,
    is_blocked boolean DEFAULT false,
    daily_limit numeric(15,2) DEFAULT 100000.00,
    monthly_limit numeric(15,2) DEFAULT 500000.00,
    pin_hash character varying(255),
    failed_attempts integer DEFAULT 0,
    last_used_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_card_brand CHECK (((card_brand)::text = ANY ((ARRAY['visa'::character varying, 'mastercard'::character varying, 'mir'::character varying])::text[]))),
    CONSTRAINT chk_card_type CHECK (((card_type)::text = ANY ((ARRAY['debit'::character varying, 'credit'::character varying])::text[]))),
    CONSTRAINT chk_expiry_date CHECK ((expiry_date > CURRENT_DATE))
);


ALTER TABLE public.cards OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 24842)
-- Name: cards_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cards_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cards_id_seq OWNER TO postgres;

--
-- TOC entry 5095 (class 0 OID 0)
-- Dependencies: 223
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- TOC entry 226 (class 1259 OID 33192)
-- Name: transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.transactions (
    id integer NOT NULL,
    from_account_id integer,
    to_account_id integer,
    amount numeric(15,2) NOT NULL,
    transaction_type character varying(20) NOT NULL,
    description character varying(255) DEFAULT ''::character varying,
    status character varying(20) DEFAULT 'completed'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT transactions_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT transactions_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'completed'::character varying, 'failed'::character varying])::text[]))),
    CONSTRAINT transactions_transaction_type_check CHECK (((transaction_type)::text = ANY ((ARRAY['internal'::character varying, 'external'::character varying])::text[])))
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 33191)
-- Name: transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.transactions_id_seq OWNER TO postgres;

--
-- TOC entry 5096 (class 0 OID 0)
-- Dependencies: 225
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- TOC entry 220 (class 1259 OID 24803)
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    phone character varying(20) NOT NULL,
    password_hash character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    first_name character varying(100),
    last_name character varying(100),
    middle_name character varying(100),
    date_of_birth date,
    passport_series character varying(10),
    passport_number character varying(20)
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 24802)
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- TOC entry 5097 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4879 (class 2604 OID 24827)
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- TOC entry 4883 (class 2604 OID 24846)
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- TOC entry 4893 (class 2604 OID 33195)
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- TOC entry 4876 (class 2604 OID 24806)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 5083 (class 0 OID 24824)
-- Dependencies: 222
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts (id, user_id, account_number, balance, account_type, created_at) FROM stdin;
6	3	40817810587738293342	556.00	debit	2026-03-02 08:38:09.882105
4	2	40817810939550505056	1100.00	debit	2026-03-01 08:36:39.94162
5	3	40817810741460871193	1050.00	debit	2026-03-01 09:14:12.09973
8	4	40817810753860572454	22099.00	debit	2026-03-03 10:13:36.895727
3	2	40817810466743232377	50000.00	credit	2025-12-16 09:47:40.586369
7	4	40817810585877899760	8574.00	debit	2026-03-03 09:48:36.12947
2	2	40817810902137755351	6611.00	debit	2025-12-16 09:32:17.431724
1	2	40817810762835588165	7742.00	debit	2025-12-15 12:36:41.732433
\.


--
-- TOC entry 5085 (class 0 OID 24843)
-- Dependencies: 224
-- Data for Name: cards; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cards (id, account_id, card_number, card_holder_name, expiry_date, cvv_hash, card_type, card_brand, is_active, is_blocked, daily_limit, monthly_limit, pin_hash, failed_attempts, last_used_at, created_at, updated_at) FROM stdin;
3	3	2865 1213 3722 6199	КОНДРАШОВ ДАНИИЛ	2030-12-16	1d28c120568c10e19b9d8abe8b66d0983fa3d2e11ee7751aca50f83c6f4a43aa	credit	mir	t	f	100000.00	500000.00	1fa5d31168b1f8e20688b733576cc0cbd36571ec57c3a00a7f9cf25bfdf86a8e	0	\N	2025-12-16 09:47:40.591415	2025-12-16 09:47:40.591415
4	4	5316 5184 1120 3903	КОНДРАШОВ ДАНИИЛ	2031-03-01	734d0759cdb4e0d0a35e4fd73749aee287e4fdcc8648b71a8d6ed591b7d4cb3f	debit	mastercard	f	t	100000.00	500000.00	d4e5f572c02d22df1f652d4ecbcd7c87c374b6dcdc1413450963da8adcc5844b	0	\N	2026-03-01 08:36:39.974735	2026-03-02 08:40:56.624262
1	1	4255 6861 0933 8624	КОНДРАШОВ ДАНИИЛ	2030-12-15	a4ecdd704d258aa841bb3f9a1e3b0cafc59bd88810e542f8e7a0519809d78fe7	debit	visa	t	f	100000.00	500000.00	a818957b3a1f9857b721ff8ff9127e971302607b483b24a8d7b82ca8c2edff35	0	\N	2025-12-15 12:36:41.747497	2026-03-02 08:56:30.493247
6	6	5709 2473 9724 9699	СИДОРОВ АЛЕКСАНДР	2031-03-02	a9346b0068335c634304afa5de1d51232a80966775613d8c1c5a0f6d231c8b1a	debit	mastercard	f	t	100000.00	500000.00	6faeda436dddd39c72b49487fd7e548d0f9e17fdad3f4305c5fae9786657dc48	0	\N	2026-03-02 08:38:09.92056	2026-03-02 11:04:06.214224
5	5	4636 6578 3008 6378	СИДОРОВ АЛЕКСАНДР	2031-03-01	3b86df3ff95ad2fd72102e34f3a721f2bdc876e12e3bd1434af8ab4cabbd5547	debit	visa	f	t	100000.00	500000.00	1bfca0e6bb66042418be4e11589130ef511625cb3599f88fea080ec700c8d720	0	\N	2026-03-01 09:14:12.129405	2026-03-02 11:04:09.17189
7	7	4674 2920 4364 2594	МИХАЙЛОВ ВАДИМ	2031-03-03	91d95f436356bc3df44d44406a139351debd062823258c8cdc67e8dadb9df256	debit	visa	t	f	100000.00	500000.00	1dab4486f81a53dac8f0be4e0aa02007a98e08e7fb8836805a757e660e154ea2	0	\N	2026-03-03 09:48:36.170338	2026-03-03 09:48:36.170338
8	8	4840 2888 2406 8552	МИХАЙЛОВ ВАДИМ	2031-03-03	5ec1a0c99d428601ce42b407ae9c675e0836a8ba591c8ca6e2a2cf5563d97ff0	debit	visa	t	f	100000.00	500000.00	0252b081bda70b478f0131b310a93cb8d79086d785fb4ae392a8c5ffc3ddc5fe	0	\N	2026-03-03 10:13:36.899738	2026-03-03 10:13:36.899738
2	2	5035 3908 5820 5050	КОНДРАШОВ ДАНИИЛ	2030-12-16	477d8dffaf92d265c56dca496167d71bfc1c34f443bc9a6677009963e6e99706	debit	mastercard	t	f	100000.00	500000.00	0f1d5b7f2da99ff77752ea981cd4bd04ab89f1bd3e3b415c6f98ea2514f431b1	0	\N	2025-12-16 09:32:17.443929	2026-03-03 15:41:13.586468
\.


--
-- TOC entry 5087 (class 0 OID 33192)
-- Dependencies: 226
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transactions (id, from_account_id, to_account_id, amount, transaction_type, description, status, created_at) FROM stdin;
1	1	2	400.00	internal		completed	2026-03-01 09:09:00.019423
2	1	5	350.00	external		completed	2026-03-01 09:15:32.812188
3	2	5	200.00	external		completed	2026-03-01 09:18:09.65565
4	2	4	100.00	internal		completed	2026-03-01 10:20:27.862102
5	\N	1	500.00	external	Пополнение счёта	completed	2026-03-02 08:12:07.341538
6	\N	3	500.00	external	Пополнение счёта	completed	2026-03-02 08:12:07.350225
7	\N	1	500.00	external	Пополнение счёта	completed	2026-03-02 08:13:19.988645
8	\N	2	1111.00	external	Пополнение счёта	completed	2026-03-02 08:26:27.904824
9	2	5	400.00	external		completed	2026-03-02 08:28:33.178123
10	\N	6	1000.00	external	Пополнение счёта	completed	2026-03-02 08:38:22.894767
11	6	1	444.00	external		completed	2026-03-02 08:38:59.468903
12	4	2	22.00	internal		completed	2026-03-02 08:43:36.308524
13	2	4	22.00	internal		completed	2026-03-02 08:44:22.495169
14	\N	4	1000.00	external	Пополнение счёта	completed	2026-03-02 08:47:19.944183
15	1	5	100.00	external		completed	2026-03-02 11:04:52.6397
16	\N	1	1000.00	external	Пополнение счёта	completed	2026-03-02 11:30:57.487864
17	1	2	300.00	internal		completed	2026-03-02 11:31:45.972665
18	\N	1	6666.00	external	Пополнение счёта	completed	2026-03-02 13:35:12.187187
19	1	2	2000.00	internal		completed	2026-03-02 16:54:26.368696
20	1	2	100.00	internal		completed	2026-03-02 16:55:18.611599
21	\N	2	3745.00	external	Пополнение счёта	completed	2026-03-03 09:22:41.658223
22	\N	7	5000.00	external	Пополнение счёта	completed	2026-03-03 10:13:56.926475
23	\N	8	25555.00	external	Пополнение счёта	completed	2026-03-03 10:14:01.989509
24	8	1	3456.00	external		completed	2026-03-03 10:14:22.596475
25	3	2	500.00	internal		completed	2026-03-03 10:17:49.358049
26	1	7	3574.00	external		completed	2026-03-03 11:43:43.513505
27	2	1	1000.00	internal		completed	2026-03-03 15:47:59.194283
\.


--
-- TOC entry 5081 (class 0 OID 24803)
-- Dependencies: 220
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, phone, password_hash, created_at, updated_at, first_name, last_name, middle_name, date_of_birth, passport_series, passport_number) FROM stdin;
2	kondrashovdevs@gmail.com	+79332211901	f49a9283c4f661cfe0d086f84b035d5042cd9d0047f6262df049f0e0837b164e	2025-12-11 10:21:59.604701	2025-12-11 10:21:59.604701	Даниил	Кондрашов	Владимирович	2002-01-19	1253	456734
3	alex.ivanov@gmail.com	+71112223344	ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f	2026-03-01 09:13:37.349434	2026-03-01 09:13:37.349434	Александр	Сидоров	Петрович	2001-02-09	6423	845263
4	vadim.mikh@yandex.ru	+72223334455	ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f	2026-03-03 08:58:36.529251	2026-03-03 08:58:36.529251	Вадим	Михайлов	Сергеевич	2002-06-23	7545	123674
\.


--
-- TOC entry 5098 (class 0 OID 0)
-- Dependencies: 221
-- Name: accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_id_seq', 8, true);


--
-- TOC entry 5099 (class 0 OID 0)
-- Dependencies: 223
-- Name: cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cards_id_seq', 8, true);


--
-- TOC entry 5100 (class 0 OID 0)
-- Dependencies: 225
-- Name: transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_id_seq', 27, true);


--
-- TOC entry 5101 (class 0 OID 0)
-- Dependencies: 219
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 4, true);


--
-- TOC entry 4912 (class 2606 OID 24836)
-- Name: accounts accounts_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_account_number_key UNIQUE (account_number);


--
-- TOC entry 4914 (class 2606 OID 24834)
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 4916 (class 2606 OID 24883)
-- Name: cards cards_card_number_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_card_number_unique UNIQUE (card_number);


--
-- TOC entry 4918 (class 2606 OID 24866)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- TOC entry 4926 (class 2606 OID 33206)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 4906 (class 2606 OID 24818)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4908 (class 2606 OID 24820)
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- TOC entry 4910 (class 2606 OID 24816)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4919 (class 1259 OID 24874)
-- Name: idx_cards_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_account_id ON public.cards USING btree (account_id);


--
-- TOC entry 4920 (class 1259 OID 24875)
-- Name: idx_cards_card_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_card_number ON public.cards USING btree (card_number);


--
-- TOC entry 4921 (class 1259 OID 24876)
-- Name: idx_cards_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_is_active ON public.cards USING btree (is_active);


--
-- TOC entry 4922 (class 1259 OID 33219)
-- Name: idx_transactions_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_created ON public.transactions USING btree (created_at DESC);


--
-- TOC entry 4923 (class 1259 OID 33217)
-- Name: idx_transactions_from; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_from ON public.transactions USING btree (from_account_id);


--
-- TOC entry 4924 (class 1259 OID 33218)
-- Name: idx_transactions_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_to ON public.transactions USING btree (to_account_id);


--
-- TOC entry 4903 (class 1259 OID 24821)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- TOC entry 4904 (class 1259 OID 24822)
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- TOC entry 4931 (class 2620 OID 24885)
-- Name: cards check_card_number_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_card_number_validity BEFORE INSERT OR UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.validate_card_number_trigger();


--
-- TOC entry 4932 (class 2620 OID 24878)
-- Name: cards trigger_update_cards_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_cards_timestamp BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.update_cards_updated_at();


--
-- TOC entry 4927 (class 2606 OID 24837)
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4928 (class 2606 OID 24869)
-- Name: cards cards_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- TOC entry 4929 (class 2606 OID 33207)
-- Name: transactions transactions_from_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_from_account_id_fkey FOREIGN KEY (from_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4930 (class 2606 OID 33212)
-- Name: transactions transactions_to_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_to_account_id_fkey FOREIGN KEY (to_account_id) REFERENCES public.accounts(id);


-- Completed on 2026-03-04 10:47:38

--
-- PostgreSQL database dump complete
--

\unrestrict ilI9sqsVHba9I2V5VI9bxAjyx5LthA66upiA3xpsRwBDkvv6yNDD99tiacUoPwy


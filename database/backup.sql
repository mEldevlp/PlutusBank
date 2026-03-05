--
-- PostgreSQL database dump
--

\restrict Q8S7No2gUc7kDc8iZupb6Ui6bBTCW29ztWr9ChTKVxZVgOkSzcKI6ijat2bMwo6

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.1

-- Started on 2026-03-05 18:44:25

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
-- TOC entry 5152 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 233 (class 1255 OID 16389)
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
-- TOC entry 234 (class 1255 OID 16390)
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
-- TOC entry 239 (class 1255 OID 16391)
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
-- TOC entry 246 (class 1255 OID 16392)
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
-- TOC entry 247 (class 1255 OID 16393)
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
-- TOC entry 219 (class 1259 OID 16394)
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts (
    id integer NOT NULL,
    user_id integer,
    account_number character varying(20) NOT NULL,
    balance numeric(15,2) DEFAULT 0.00,
    account_type character varying(50) DEFAULT 'debit'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT accounts_account_type_check CHECK (((account_type)::text = ANY ((ARRAY['debit'::character varying, 'credit'::character varying, 'loan'::character varying, 'bank_loan_fund'::character varying])::text[])))
);


ALTER TABLE public.accounts OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16402)
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
-- TOC entry 5153 (class 0 OID 0)
-- Dependencies: 220
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- TOC entry 221 (class 1259 OID 16403)
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
    CONSTRAINT chk_card_brand CHECK (((card_brand)::text = ANY (ARRAY[('visa'::character varying)::text, ('mastercard'::character varying)::text, ('mir'::character varying)::text]))),
    CONSTRAINT chk_card_type CHECK (((card_type)::text = ANY (ARRAY[('debit'::character varying)::text, ('credit'::character varying)::text]))),
    CONSTRAINT chk_expiry_date CHECK ((expiry_date > CURRENT_DATE))
);


ALTER TABLE public.cards OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 16424)
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
-- TOC entry 5154 (class 0 OID 0)
-- Dependencies: 222
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- TOC entry 228 (class 1259 OID 16510)
-- Name: loan_products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loan_products (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    category character varying(50) NOT NULL,
    annual_rate numeric(5,2) NOT NULL,
    min_amount numeric(15,2) NOT NULL,
    max_amount numeric(15,2) NOT NULL,
    min_term_months integer NOT NULL,
    max_term_months integer NOT NULL,
    description text DEFAULT ''::text,
    is_active boolean DEFAULT true,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_amounts CHECK (((min_amount > (0)::numeric) AND (max_amount >= min_amount))),
    CONSTRAINT chk_category CHECK (((category)::text = ANY ((ARRAY['mortgage'::character varying, 'auto'::character varying, 'electronics'::character varying, 'personal'::character varying])::text[]))),
    CONSTRAINT chk_rate CHECK (((annual_rate > (0)::numeric) AND (annual_rate < (100)::numeric))),
    CONSTRAINT chk_terms CHECK (((min_term_months > 0) AND (max_term_months >= min_term_months)))
);


ALTER TABLE public.loan_products OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16509)
-- Name: loan_products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loan_products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loan_products_id_seq OWNER TO postgres;

--
-- TOC entry 5155 (class 0 OID 0)
-- Dependencies: 227
-- Name: loan_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_products_id_seq OWNED BY public.loan_products.id;


--
-- TOC entry 232 (class 1259 OID 16579)
-- Name: loan_schedule; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loan_schedule (
    id integer NOT NULL,
    loan_id integer NOT NULL,
    payment_number integer NOT NULL,
    due_date date NOT NULL,
    principal_part numeric(15,2) NOT NULL,
    interest_part numeric(15,2) NOT NULL,
    total_amount numeric(15,2) NOT NULL,
    status character varying(20) DEFAULT 'pending'::character varying,
    paid_at timestamp without time zone,
    transaction_id integer,
    CONSTRAINT chk_schedule_status CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'paid'::character varying, 'overdue'::character varying, 'partially_paid'::character varying])::text[])))
);


ALTER TABLE public.loan_schedule OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 16578)
-- Name: loan_schedule_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loan_schedule_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loan_schedule_id_seq OWNER TO postgres;

--
-- TOC entry 5156 (class 0 OID 0)
-- Dependencies: 231
-- Name: loan_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_schedule_id_seq OWNED BY public.loan_schedule.id;


--
-- TOC entry 230 (class 1259 OID 16534)
-- Name: loans; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.loans (
    id integer NOT NULL,
    user_id integer NOT NULL,
    product_id integer NOT NULL,
    target_account_id integer NOT NULL,
    bank_account_id integer NOT NULL,
    principal numeric(15,2) NOT NULL,
    annual_rate numeric(5,2) NOT NULL,
    term_months integer NOT NULL,
    monthly_payment numeric(15,2) NOT NULL,
    total_paid numeric(15,2) DEFAULT 0,
    remaining_balance numeric(15,2) NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying,
    issued_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    next_payment_date date NOT NULL,
    closed_at timestamp without time zone,
    CONSTRAINT chk_loan_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'closed'::character varying, 'overdue'::character varying, 'defaulted'::character varying])::text[]))),
    CONSTRAINT chk_principal CHECK ((principal > (0)::numeric))
);


ALTER TABLE public.loans OWNER TO postgres;

--
-- TOC entry 229 (class 1259 OID 16533)
-- Name: loans_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.loans_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.loans_id_seq OWNER TO postgres;

--
-- TOC entry 5157 (class 0 OID 0)
-- Dependencies: 229
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- TOC entry 223 (class 1259 OID 16425)
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
    CONSTRAINT transactions_status_check CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('completed'::character varying)::text, ('failed'::character varying)::text]))),
    CONSTRAINT transactions_transaction_type_check CHECK (((transaction_type)::text = ANY ((ARRAY['internal'::character varying, 'external'::character varying, 'loan_disbursement'::character varying, 'loan_payment'::character varying])::text[])))
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 16437)
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
-- TOC entry 5158 (class 0 OID 0)
-- Dependencies: 224
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- TOC entry 225 (class 1259 OID 16438)
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
    passport_number character varying(20),
    address character varying(255) DEFAULT ''::character varying,
    primary_account_id integer,
    is_system_user boolean DEFAULT false
);


ALTER TABLE public.users OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 16449)
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
-- TOC entry 5159 (class 0 OID 0)
-- Dependencies: 226
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4891 (class 2604 OID 16450)
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- TOC entry 4895 (class 2604 OID 16451)
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- TOC entry 4914 (class 2604 OID 16513)
-- Name: loan_products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products ALTER COLUMN id SET DEFAULT nextval('public.loan_products_id_seq'::regclass);


--
-- TOC entry 4922 (class 2604 OID 16582)
-- Name: loan_schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule ALTER COLUMN id SET DEFAULT nextval('public.loan_schedule_id_seq'::regclass);


--
-- TOC entry 4918 (class 2604 OID 16537)
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- TOC entry 4905 (class 2604 OID 16452)
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- TOC entry 4909 (class 2604 OID 16453)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 5133 (class 0 OID 16394)
-- Dependencies: 219
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts (id, user_id, account_number, balance, account_type, created_at) FROM stdin;
6	3	40817810587738293342	556.00	debit	2026-03-02 08:38:09.882105
4	2	40817810939550505056	1100.00	debit	2026-03-01 08:36:39.94162
5	3	40817810741460871193	1050.00	debit	2026-03-01 09:14:12.09973
3	2	40817810466743232377	50000.00	credit	2025-12-16 09:47:40.586369
1	2	40817810762835588165	8543.00	debit	2025-12-15 12:36:41.732433
7	4	40817810585877899760	9884.00	debit	2026-03-03 09:48:36.12947
9	5	40817810669102412929	100128380.40	bank_loan_fund	2026-03-05 14:55:28.75798
2	2	40817810902137755351	53449.84	debit	2025-12-16 09:32:17.431724
8	4	40817810753860572454	50768.76	debit	2026-03-03 10:13:36.895727
\.


--
-- TOC entry 5135 (class 0 OID 16403)
-- Dependencies: 221
-- Data for Name: cards; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cards (id, account_id, card_number, card_holder_name, expiry_date, cvv_hash, card_type, card_brand, is_active, is_blocked, daily_limit, monthly_limit, pin_hash, failed_attempts, last_used_at, created_at, updated_at) FROM stdin;
3	3	2865 1213 3722 6199	КОНДРАШОВ ДАНИИЛ	2030-12-16	1d28c120568c10e19b9d8abe8b66d0983fa3d2e11ee7751aca50f83c6f4a43aa	credit	mir	t	f	100000.00	500000.00	1fa5d31168b1f8e20688b733576cc0cbd36571ec57c3a00a7f9cf25bfdf86a8e	0	\N	2025-12-16 09:47:40.591415	2025-12-16 09:47:40.591415
4	4	5316 5184 1120 3903	КОНДРАШОВ ДАНИИЛ	2031-03-01	734d0759cdb4e0d0a35e4fd73749aee287e4fdcc8648b71a8d6ed591b7d4cb3f	debit	mastercard	f	t	100000.00	500000.00	d4e5f572c02d22df1f652d4ecbcd7c87c374b6dcdc1413450963da8adcc5844b	0	\N	2026-03-01 08:36:39.974735	2026-03-02 08:40:56.624262
6	6	5709 2473 9724 9699	СИДОРОВ АЛЕКСАНДР	2031-03-02	a9346b0068335c634304afa5de1d51232a80966775613d8c1c5a0f6d231c8b1a	debit	mastercard	f	t	100000.00	500000.00	6faeda436dddd39c72b49487fd7e548d0f9e17fdad3f4305c5fae9786657dc48	0	\N	2026-03-02 08:38:09.92056	2026-03-02 11:04:06.214224
5	5	4636 6578 3008 6378	СИДОРОВ АЛЕКСАНДР	2031-03-01	3b86df3ff95ad2fd72102e34f3a721f2bdc876e12e3bd1434af8ab4cabbd5547	debit	visa	f	t	100000.00	500000.00	1bfca0e6bb66042418be4e11589130ef511625cb3599f88fea080ec700c8d720	0	\N	2026-03-01 09:14:12.129405	2026-03-02 11:04:09.17189
7	7	4674 2920 4364 2594	МИХАЙЛОВ ВАДИМ	2031-03-03	91d95f436356bc3df44d44406a139351debd062823258c8cdc67e8dadb9df256	debit	visa	t	f	100000.00	500000.00	1dab4486f81a53dac8f0be4e0aa02007a98e08e7fb8836805a757e660e154ea2	0	\N	2026-03-03 09:48:36.170338	2026-03-03 09:48:36.170338
8	8	4840 2888 2406 8552	МИХАЙЛОВ ВАДИМ	2031-03-03	5ec1a0c99d428601ce42b407ae9c675e0836a8ba591c8ca6e2a2cf5563d97ff0	debit	visa	t	f	100000.00	500000.00	0252b081bda70b478f0131b310a93cb8d79086d785fb4ae392a8c5ffc3ddc5fe	0	\N	2026-03-03 10:13:36.899738	2026-03-03 10:13:36.899738
2	2	5035 3908 5820 5050	КОНДРАШОВ ДАНИИЛ	2030-12-16	477d8dffaf92d265c56dca496167d71bfc1c34f443bc9a6677009963e6e99706	debit	mastercard	t	f	100000.00	500000.00	0f1d5b7f2da99ff77752ea981cd4bd04ab89f1bd3e3b415c6f98ea2514f431b1	0	\N	2025-12-16 09:32:17.443929	2026-03-03 15:41:13.586468
1	1	4255 6861 0933 8624	КОНДРАШОВ ДАНИИЛ	2030-12-15	a4ecdd704d258aa841bb3f9a1e3b0cafc59bd88810e542f8e7a0519809d78fe7	debit	visa	t	f	100000.00	500000.00	a818957b3a1f9857b721ff8ff9127e971302607b483b24a8d7b82ca8c2edff35	0	\N	2025-12-15 12:36:41.747497	2026-03-05 09:19:43.630619
\.


--
-- TOC entry 5142 (class 0 OID 16510)
-- Dependencies: 228
-- Data for Name: loan_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_products (id, name, category, annual_rate, min_amount, max_amount, min_term_months, max_term_months, description, is_active, created_at) FROM stdin;
1	Ипотека	mortgage	9.90	500000.00	15000000.00	12	360	Кредит на покупку жилья по выгодной ставке	t	2026-03-05 14:55:28.75798
2	Автокредит	auto	12.50	100000.00	5000000.00	6	84	Кредит на покупку нового или подержанного автомобиля	t	2026-03-05 14:55:28.75798
3	Кредит на технику	electronics	14.90	10000.00	500000.00	3	36	Кредит на покупку бытовой техники и электроники	t	2026-03-05 14:55:28.75798
4	Потребительский	personal	16.50	30000.00	3000000.00	3	60	Кредит на любые цели без залога	t	2026-03-05 14:55:28.75798
\.


--
-- TOC entry 5146 (class 0 OID 16579)
-- Dependencies: 232
-- Data for Name: loan_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_schedule (id, loan_id, payment_number, due_date, principal_part, interest_part, total_amount, status, paid_at, transaction_id) FROM stdin;
13	2	1	2026-04-05	46113.31	13020.83	59134.14	paid	2026-03-05 12:46:02.521728	35
14	2	2	2026-05-05	46593.65	12540.49	59134.14	paid	2026-03-05 12:46:34.688555	37
15	2	3	2026-06-05	47079.00	12055.14	59134.14	paid	2026-03-05 12:46:35.504169	38
16	2	4	2026-07-05	47569.41	11564.73	59134.14	paid	2026-03-05 12:46:36.234331	39
17	2	5	2026-08-05	48064.93	11069.21	59134.14	paid	2026-03-05 12:46:36.725601	40
18	2	6	2026-09-05	48565.60	10568.54	59134.14	paid	2026-03-05 12:46:37.121868	41
19	2	7	2026-10-05	49071.49	10062.65	59134.14	paid	2026-03-05 12:46:38.839773	42
20	2	8	2026-11-05	49582.65	9551.49	59134.14	paid	2026-03-05 12:46:39.127962	43
21	2	9	2026-12-05	50099.14	9035.00	59134.14	paid	2026-03-05 12:46:39.339663	44
22	2	10	2027-01-05	50621.01	8513.13	59134.14	paid	2026-03-05 12:46:39.535029	45
23	2	11	2027-02-05	51148.31	7985.83	59134.14	paid	2026-03-05 12:46:39.720181	46
24	2	12	2027-03-05	51681.10	7453.04	59134.14	paid	2026-03-05 12:46:39.910727	47
25	2	13	2027-04-05	52219.45	6914.69	59134.14	paid	2026-03-05 12:46:43.873927	48
26	2	14	2027-05-05	52763.40	6370.74	59134.14	paid	2026-03-05 12:46:44.087314	49
27	2	15	2027-06-05	53313.02	5821.12	59134.14	paid	2026-03-05 12:46:44.273532	50
28	2	16	2027-07-05	53868.36	5265.78	59134.14	paid	2026-03-05 12:46:44.458018	51
29	2	17	2027-08-05	54429.49	4704.65	59134.14	paid	2026-03-05 12:46:44.641854	52
30	2	18	2027-09-05	54996.47	4137.67	59134.14	paid	2026-03-05 12:46:44.842696	53
31	2	19	2027-10-05	55569.35	3564.79	59134.14	paid	2026-03-05 12:46:49.459067	54
32	2	20	2027-11-05	56148.19	2985.95	59134.14	paid	2026-03-05 12:46:49.66801	55
33	2	21	2027-12-05	56733.07	2401.07	59134.14	paid	2026-03-05 12:46:49.850628	56
34	2	22	2028-01-05	57324.04	1810.10	59134.14	paid	2026-03-05 12:46:50.040392	57
35	2	23	2028-02-05	57921.17	1212.97	59134.14	paid	2026-03-05 12:46:56.441176	58
36	2	24	2028-03-05	58524.39	609.63	59134.02	paid	2026-03-05 12:47:01.417805	59
1	1	1	2026-04-05	7721.76	1375.00	9096.76	paid	2026-03-05 14:11:33.034594	60
2	1	2	2026-05-05	7827.93	1268.83	9096.76	paid	2026-03-05 14:11:39.377447	61
3	1	3	2026-06-05	7935.57	1161.19	9096.76	paid	2026-03-05 14:11:40.170925	62
4	1	4	2026-07-05	8044.68	1052.08	9096.76	paid	2026-03-05 14:11:41.456875	63
5	1	5	2026-08-05	8155.30	941.46	9096.76	paid	2026-03-05 14:11:42.316834	64
6	1	6	2026-09-05	8267.43	829.33	9096.76	paid	2026-03-05 14:11:42.883756	65
7	1	7	2026-10-05	8381.11	715.65	9096.76	paid	2026-03-05 14:11:43.384782	66
8	1	8	2026-11-05	8496.35	600.41	9096.76	paid	2026-03-05 14:11:43.79431	67
9	1	9	2026-12-05	8613.17	483.59	9096.76	paid	2026-03-05 14:11:44.324688	68
10	1	10	2027-01-05	8731.61	365.15	9096.76	paid	2026-03-05 14:11:47.811752	69
11	1	11	2027-02-05	8851.67	245.09	9096.76	paid	2026-03-05 14:12:22.665556	70
12	1	12	2027-03-05	8973.42	123.38	9096.80	paid	2026-03-05 14:12:39.470973	72
37	3	1	2026-04-05	9754.73	620.83	10375.56	pending	\N	\N
38	3	2	2026-05-05	9875.85	499.71	10375.56	pending	\N	\N
39	3	3	2026-06-05	9998.47	377.09	10375.56	pending	\N	\N
40	3	4	2026-07-05	10122.62	252.94	10375.56	pending	\N	\N
41	3	5	2026-08-05	10248.33	127.25	10375.58	pending	\N	\N
\.


--
-- TOC entry 5144 (class 0 OID 16534)
-- Dependencies: 230
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loans (id, user_id, product_id, target_account_id, bank_account_id, principal, annual_rate, term_months, monthly_payment, total_paid, remaining_balance, status, issued_at, next_payment_date, closed_at) FROM stdin;
2	4	2	8	9	1250000.00	12.50	24	59134.14	1419219.24	0.01	active	2026-03-05 12:44:51.254653	2028-04-05	\N
1	2	4	2	9	100000.00	16.50	12	9096.76	109161.16	0.00	closed	2026-03-05 12:35:13.777791	2027-03-05	2026-03-05 14:12:39.470973
3	2	3	2	9	50000.00	14.90	5	10375.56	0.00	51877.82	active	2026-03-05 15:41:08.236218	2026-04-05	\N
\.


--
-- TOC entry 5137 (class 0 OID 16425)
-- Dependencies: 223
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
28	\N	2	1000.00	external	Пополнение счёта	completed	2026-03-04 08:20:15.682681
29	8	1	1000.00	external		completed	2026-03-05 10:38:36.09644
30	8	2	1111.00	external		completed	2026-03-05 10:40:23.48647
31	2	7	1111.00	external		completed	2026-03-05 11:15:01.109595
32	1	7	199.00	external		completed	2026-03-05 11:27:20.022764
33	9	2	100000.00	loan_disbursement	Выдача кредита	completed	2026-03-05 12:35:13.777791
34	9	8	1250000.00	loan_disbursement	Выдача кредита	completed	2026-03-05 12:44:51.254653
35	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:02.521728
36	\N	8	200000.00	external	Пополнение счёта	completed	2026-03-05 12:46:27.944054
37	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:34.688555
38	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:35.504169
39	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:36.234331
40	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:36.725601
41	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:37.121868
42	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:38.839773
43	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:39.127962
44	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:39.339663
45	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:39.535029
46	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:39.720181
47	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:39.910727
48	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:43.873927
49	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:44.087314
50	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:44.273532
51	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:44.458018
52	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:44.641854
53	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:44.842696
54	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:49.459067
55	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:49.66801
56	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:49.850628
57	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:50.040392
58	8	9	59134.14	loan_payment	Погашение кредита	completed	2026-03-05 12:46:56.441176
59	8	9	59134.02	loan_payment	Погашение кредита	completed	2026-03-05 12:47:01.417805
60	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:33.034594
61	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:39.377447
62	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:40.170925
63	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:41.456875
64	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:42.316834
65	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:42.883756
66	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:43.384782
67	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:43.79431
68	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:44.324688
69	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:11:47.811752
70	2	9	9096.76	loan_payment	Погашение кредита	completed	2026-03-05 14:12:22.665556
71	\N	2	5000.00	external	Пополнение счёта	completed	2026-03-05 14:12:32.114037
72	2	9	9096.80	loan_payment	Погашение кредита	completed	2026-03-05 14:12:39.470973
73	9	2	50000.00	loan_disbursement	Выдача кредита	completed	2026-03-05 15:41:08.236218
\.


--
-- TOC entry 5139 (class 0 OID 16438)
-- Dependencies: 225
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, phone, password_hash, created_at, updated_at, first_name, last_name, middle_name, date_of_birth, passport_series, passport_number, address, primary_account_id, is_system_user) FROM stdin;
3	alex.ivanov@gmail.com	+71112223344	ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f	2026-03-01 09:13:37.349434	2026-03-01 09:13:37.349434	Александр	Сидоров	Петрович	2001-02-09	6423	845263	г. Москва	5	f
4	vadim.mikh@yandex.ru	+72223334455	ef797c8118f02dfb649607dd5d3f8c7623048c9c063d532cc95c5ed7a898a64f	2026-03-03 08:58:36.529251	2026-03-03 08:58:36.529251	Вадим	Михайлов	Сергеевич	2002-06-23	7545	123674	г. Москва	7	f
2	kondrashovdevs@gmail.com	+79332211901	f49a9283c4f661cfe0d086f84b035d5042cd9d0047f6262df049f0e0837b164e	2025-12-11 10:21:59.604701	2025-12-11 10:21:59.604701	Даниил	Кондрашов	Владимирович	2002-01-19	1253	456734	г. Великий Новгород	2	f
5	system@bank.internal	+70000000000	SYSTEM_NO_LOGIN	2026-03-05 14:55:28.75798	2026-03-05 14:55:28.75798	PlutusBank	System		2000-01-01	0000	000000	Системный аккаунт	\N	t
\.


--
-- TOC entry 5160 (class 0 OID 0)
-- Dependencies: 220
-- Name: accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_id_seq', 9, true);


--
-- TOC entry 5161 (class 0 OID 0)
-- Dependencies: 222
-- Name: cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cards_id_seq', 8, true);


--
-- TOC entry 5162 (class 0 OID 0)
-- Dependencies: 227
-- Name: loan_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_products_id_seq', 4, true);


--
-- TOC entry 5163 (class 0 OID 0)
-- Dependencies: 231
-- Name: loan_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_schedule_id_seq', 41, true);


--
-- TOC entry 5164 (class 0 OID 0)
-- Dependencies: 229
-- Name: loans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loans_id_seq', 3, true);


--
-- TOC entry 5165 (class 0 OID 0)
-- Dependencies: 224
-- Name: transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_id_seq', 73, true);


--
-- TOC entry 5166 (class 0 OID 0)
-- Dependencies: 226
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 5, true);


--
-- TOC entry 4939 (class 2606 OID 16455)
-- Name: accounts accounts_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_account_number_key UNIQUE (account_number);


--
-- TOC entry 4941 (class 2606 OID 16457)
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 4943 (class 2606 OID 16459)
-- Name: cards cards_card_number_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_card_number_unique UNIQUE (card_number);


--
-- TOC entry 4945 (class 2606 OID 16461)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- TOC entry 4963 (class 2606 OID 16532)
-- Name: loan_products loan_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products
    ADD CONSTRAINT loan_products_pkey PRIMARY KEY (id);


--
-- TOC entry 4972 (class 2606 OID 16593)
-- Name: loan_schedule loan_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_pkey PRIMARY KEY (id);


--
-- TOC entry 4967 (class 2606 OID 16555)
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- TOC entry 4953 (class 2606 OID 16463)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 4957 (class 2606 OID 16465)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4959 (class 2606 OID 16467)
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- TOC entry 4961 (class 2606 OID 16469)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4946 (class 1259 OID 16470)
-- Name: idx_cards_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_account_id ON public.cards USING btree (account_id);


--
-- TOC entry 4947 (class 1259 OID 16471)
-- Name: idx_cards_card_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_card_number ON public.cards USING btree (card_number);


--
-- TOC entry 4948 (class 1259 OID 16472)
-- Name: idx_cards_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_is_active ON public.cards USING btree (is_active);


--
-- TOC entry 4964 (class 1259 OID 16577)
-- Name: idx_loans_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_status ON public.loans USING btree (status);


--
-- TOC entry 4965 (class 1259 OID 16576)
-- Name: idx_loans_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_user ON public.loans USING btree (user_id);


--
-- TOC entry 4968 (class 1259 OID 16606)
-- Name: idx_schedule_due; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_due ON public.loan_schedule USING btree (due_date);


--
-- TOC entry 4969 (class 1259 OID 16604)
-- Name: idx_schedule_loan; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_loan ON public.loan_schedule USING btree (loan_id);


--
-- TOC entry 4970 (class 1259 OID 16605)
-- Name: idx_schedule_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_status ON public.loan_schedule USING btree (status);


--
-- TOC entry 4949 (class 1259 OID 16473)
-- Name: idx_transactions_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_created ON public.transactions USING btree (created_at DESC);


--
-- TOC entry 4950 (class 1259 OID 16474)
-- Name: idx_transactions_from; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_from ON public.transactions USING btree (from_account_id);


--
-- TOC entry 4951 (class 1259 OID 16475)
-- Name: idx_transactions_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_to ON public.transactions USING btree (to_account_id);


--
-- TOC entry 4954 (class 1259 OID 16476)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- TOC entry 4955 (class 1259 OID 16477)
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- TOC entry 4984 (class 2620 OID 16478)
-- Name: cards check_card_number_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_card_number_validity BEFORE INSERT OR UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.validate_card_number_trigger();


--
-- TOC entry 4985 (class 2620 OID 16479)
-- Name: cards trigger_update_cards_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_cards_timestamp BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.update_cards_updated_at();


--
-- TOC entry 4973 (class 2606 OID 16480)
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4974 (class 2606 OID 16485)
-- Name: cards cards_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- TOC entry 4982 (class 2606 OID 16594)
-- Name: loan_schedule loan_schedule_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- TOC entry 4983 (class 2606 OID 16599)
-- Name: loan_schedule loan_schedule_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 4978 (class 2606 OID 16571)
-- Name: loans loans_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4979 (class 2606 OID 16561)
-- Name: loans loans_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.loan_products(id);


--
-- TOC entry 4980 (class 2606 OID 16566)
-- Name: loans loans_target_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_target_account_id_fkey FOREIGN KEY (target_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4981 (class 2606 OID 16556)
-- Name: loans loans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 4975 (class 2606 OID 16490)
-- Name: transactions transactions_from_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_from_account_id_fkey FOREIGN KEY (from_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4976 (class 2606 OID 16495)
-- Name: transactions transactions_to_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_to_account_id_fkey FOREIGN KEY (to_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4977 (class 2606 OID 16501)
-- Name: users users_primary_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_primary_account_id_fkey FOREIGN KEY (primary_account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


-- Completed on 2026-03-05 18:44:25

--
-- PostgreSQL database dump complete
--

\unrestrict Q8S7No2gUc7kDc8iZupb6Ui6bBTCW29ztWr9ChTKVxZVgOkSzcKI6ijat2bMwo6


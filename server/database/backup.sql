--
-- PostgreSQL database dump
--

\restrict 1J0fEwdrAvdVbj9M4RHcEs5VSCurD4bruRtnPNNbvJzlFsucChmb5i7PeVH6hPM

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.1

-- Started on 2026-03-09 13:39:03

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
-- TOC entry 238 (class 1255 OID 16389)
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
-- TOC entry 239 (class 1255 OID 16390)
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
-- TOC entry 244 (class 1255 OID 16391)
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
-- TOC entry 251 (class 1255 OID 16392)
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
-- TOC entry 252 (class 1255 OID 16393)
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
-- TOC entry 5165 (class 0 OID 0)
-- Dependencies: 220
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


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
-- TOC entry 234 (class 1259 OID 16615)
-- Name: active_loans_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.active_loans_view AS
 SELECT l.id AS loan_id,
    (((u.last_name)::text || ' '::text) || (u.first_name)::text) AS client_name,
    u.phone,
    lp.name AS product_name,
    lp.category,
    l.principal,
    l.annual_rate,
    l.term_months,
    l.monthly_payment,
    l.remaining_balance,
    l.issued_at,
    l.next_payment_date
   FROM ((public.loans l
     JOIN public.users u ON ((l.user_id = u.id)))
     JOIN public.loan_products lp ON ((l.product_id = lp.id)))
  WHERE ((l.status)::text = 'active'::text);


ALTER VIEW public.active_loans_view OWNER TO postgres;

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
-- TOC entry 5166 (class 0 OID 0)
-- Dependencies: 222
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- TOC entry 237 (class 1259 OID 16634)
-- Name: loan_products_active_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.loan_products_active_view AS
 SELECT id,
    name,
    category,
    annual_rate,
    min_amount,
    max_amount,
    min_term_months,
    max_term_months,
    description
   FROM public.loan_products
  WHERE (is_active = true);


ALTER VIEW public.loan_products_active_view OWNER TO postgres;

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
-- TOC entry 5167 (class 0 OID 0)
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
-- TOC entry 5168 (class 0 OID 0)
-- Dependencies: 231
-- Name: loan_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_schedule_id_seq OWNED BY public.loan_schedule.id;


--
-- TOC entry 236 (class 1259 OID 16629)
-- Name: loan_schedule_summary_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.loan_schedule_summary_view AS
 SELECT loan_id,
    count(*) AS total_payments,
    count(*) FILTER (WHERE ((status)::text = 'paid'::text)) AS paid_count,
    count(*) FILTER (WHERE ((status)::text = 'pending'::text)) AS pending_count,
    count(*) FILTER (WHERE ((status)::text = 'overdue'::text)) AS overdue_count,
    COALESCE(sum(total_amount) FILTER (WHERE ((status)::text = 'paid'::text)), (0)::numeric) AS total_paid_amount,
    COALESCE(sum(total_amount) FILTER (WHERE ((status)::text = 'pending'::text)), (0)::numeric) AS total_pending_amount
   FROM public.loan_schedule ls
  GROUP BY loan_id;


ALTER VIEW public.loan_schedule_summary_view OWNER TO postgres;

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
-- TOC entry 5169 (class 0 OID 0)
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
-- TOC entry 235 (class 1259 OID 16622)
-- Name: transaction_history_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.transaction_history_view AS
 SELECT t.id,
    t.amount,
    t.transaction_type,
    t.description,
    t.status,
    t.created_at,
    t.from_account_id,
    t.to_account_id,
    ((((fu.last_name)::text || ' '::text) || "left"((fu.first_name)::text, 1)) || '.'::text) AS from_name,
    ((((tu.last_name)::text || ' '::text) || "left"((tu.first_name)::text, 1)) || '.'::text) AS to_name,
    "right"((fc.card_number)::text, 4) AS from_card_last4,
    "right"((tc.card_number)::text, 4) AS to_card_last4
   FROM ((((((public.transactions t
     LEFT JOIN public.accounts fa ON ((t.from_account_id = fa.id)))
     LEFT JOIN public.accounts ta ON ((t.to_account_id = ta.id)))
     LEFT JOIN public.users fu ON ((fa.user_id = fu.id)))
     LEFT JOIN public.users tu ON ((ta.user_id = tu.id)))
     LEFT JOIN public.cards fc ON ((fc.account_id = fa.id)))
     LEFT JOIN public.cards tc ON ((tc.account_id = ta.id)));


ALTER VIEW public.transaction_history_view OWNER TO postgres;

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
-- TOC entry 5170 (class 0 OID 0)
-- Dependencies: 224
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- TOC entry 233 (class 1259 OID 16607)
-- Name: user_cards_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_cards_view AS
 SELECT c.id AS card_id,
    c.card_number,
    c.card_holder_name,
    c.card_type,
    c.card_brand,
    c.is_active,
    c.is_blocked,
    c.expiry_date,
    c.daily_limit,
    c.monthly_limit,
    a.id AS account_id,
    a.account_number,
    a.balance,
    u.id AS user_id
   FROM ((public.cards c
     JOIN public.accounts a ON ((c.account_id = a.id)))
     JOIN public.users u ON ((a.user_id = u.id)));


ALTER VIEW public.user_cards_view OWNER TO postgres;

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
-- TOC entry 5171 (class 0 OID 0)
-- Dependencies: 226
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4911 (class 2604 OID 16450)
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- TOC entry 4915 (class 2604 OID 16451)
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- TOC entry 4934 (class 2604 OID 16513)
-- Name: loan_products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products ALTER COLUMN id SET DEFAULT nextval('public.loan_products_id_seq'::regclass);


--
-- TOC entry 4942 (class 2604 OID 16582)
-- Name: loan_schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule ALTER COLUMN id SET DEFAULT nextval('public.loan_schedule_id_seq'::regclass);


--
-- TOC entry 4938 (class 2604 OID 16537)
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- TOC entry 4925 (class 2604 OID 16452)
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- TOC entry 4929 (class 2604 OID 16453)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 4959 (class 2606 OID 16455)
-- Name: accounts accounts_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_account_number_key UNIQUE (account_number);


--
-- TOC entry 4961 (class 2606 OID 16457)
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 4963 (class 2606 OID 16459)
-- Name: cards cards_card_number_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_card_number_unique UNIQUE (card_number);


--
-- TOC entry 4965 (class 2606 OID 16461)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- TOC entry 4983 (class 2606 OID 16532)
-- Name: loan_products loan_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products
    ADD CONSTRAINT loan_products_pkey PRIMARY KEY (id);


--
-- TOC entry 4992 (class 2606 OID 16593)
-- Name: loan_schedule loan_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_pkey PRIMARY KEY (id);


--
-- TOC entry 4987 (class 2606 OID 16555)
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- TOC entry 4973 (class 2606 OID 16463)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 4977 (class 2606 OID 16465)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4979 (class 2606 OID 16467)
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- TOC entry 4981 (class 2606 OID 16469)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4966 (class 1259 OID 16470)
-- Name: idx_cards_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_account_id ON public.cards USING btree (account_id);


--
-- TOC entry 4967 (class 1259 OID 16471)
-- Name: idx_cards_card_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_card_number ON public.cards USING btree (card_number);


--
-- TOC entry 4968 (class 1259 OID 16472)
-- Name: idx_cards_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_is_active ON public.cards USING btree (is_active);


--
-- TOC entry 4984 (class 1259 OID 16577)
-- Name: idx_loans_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_status ON public.loans USING btree (status);


--
-- TOC entry 4985 (class 1259 OID 16576)
-- Name: idx_loans_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_user ON public.loans USING btree (user_id);


--
-- TOC entry 4988 (class 1259 OID 16606)
-- Name: idx_schedule_due; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_due ON public.loan_schedule USING btree (due_date);


--
-- TOC entry 4989 (class 1259 OID 16604)
-- Name: idx_schedule_loan; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_loan ON public.loan_schedule USING btree (loan_id);


--
-- TOC entry 4990 (class 1259 OID 16605)
-- Name: idx_schedule_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_status ON public.loan_schedule USING btree (status);


--
-- TOC entry 4969 (class 1259 OID 16473)
-- Name: idx_transactions_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_created ON public.transactions USING btree (created_at DESC);


--
-- TOC entry 4970 (class 1259 OID 16474)
-- Name: idx_transactions_from; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_from ON public.transactions USING btree (from_account_id);


--
-- TOC entry 4971 (class 1259 OID 16475)
-- Name: idx_transactions_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_to ON public.transactions USING btree (to_account_id);


--
-- TOC entry 4974 (class 1259 OID 16476)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- TOC entry 4975 (class 1259 OID 16477)
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- TOC entry 5158 (class 2618 OID 16638)
-- Name: active_loans_view protect_loan_delete; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE protect_loan_delete AS
    ON DELETE TO public.active_loans_view DO INSTEAD  UPDATE public.loans SET status = 'closed'::character varying, closed_at = CURRENT_TIMESTAMP
  WHERE (loans.id = old.loan_id);


--
-- TOC entry 5159 (class 2618 OID 16639)
-- Name: user_cards_view update_card_limits; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE update_card_limits AS
    ON UPDATE TO public.user_cards_view DO INSTEAD  UPDATE public.cards SET daily_limit = new.daily_limit, monthly_limit = new.monthly_limit
  WHERE (cards.id = old.card_id);


--
-- TOC entry 5004 (class 2620 OID 16478)
-- Name: cards check_card_number_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_card_number_validity BEFORE INSERT OR UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.validate_card_number_trigger();


--
-- TOC entry 5005 (class 2620 OID 16479)
-- Name: cards trigger_update_cards_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_cards_timestamp BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.update_cards_updated_at();


--
-- TOC entry 4993 (class 2606 OID 16480)
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4994 (class 2606 OID 16485)
-- Name: cards cards_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- TOC entry 5002 (class 2606 OID 16594)
-- Name: loan_schedule loan_schedule_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- TOC entry 5003 (class 2606 OID 16599)
-- Name: loan_schedule loan_schedule_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 4998 (class 2606 OID 16571)
-- Name: loans loans_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4999 (class 2606 OID 16561)
-- Name: loans loans_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.loan_products(id);


--
-- TOC entry 5000 (class 2606 OID 16566)
-- Name: loans loans_target_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_target_account_id_fkey FOREIGN KEY (target_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5001 (class 2606 OID 16556)
-- Name: loans loans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 4995 (class 2606 OID 16490)
-- Name: transactions transactions_from_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_from_account_id_fkey FOREIGN KEY (from_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4996 (class 2606 OID 16495)
-- Name: transactions transactions_to_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_to_account_id_fkey FOREIGN KEY (to_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4997 (class 2606 OID 16501)
-- Name: users users_primary_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_primary_account_id_fkey FOREIGN KEY (primary_account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


-- Completed on 2026-03-09 13:39:03

--
-- PostgreSQL database dump complete
--

\unrestrict 1J0fEwdrAvdVbj9M4RHcEs5VSCurD4bruRtnPNNbvJzlFsucChmb5i7PeVH6hPM


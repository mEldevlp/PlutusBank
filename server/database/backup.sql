--
-- PostgreSQL database dump
--

\restrict 70FRye9tUVwnFNxCm1Szn6tbgvZqBSwWGFFdgil3ejsj7NwBlemW0lpARbl87Bl

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-05-02 14:16:53

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
-- TOC entry 5179 (class 0 OID 0)
-- Dependencies: 4
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 238 (class 1255 OID 41413)
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
-- TOC entry 239 (class 1255 OID 41414)
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
-- TOC entry 244 (class 1255 OID 41415)
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
-- TOC entry 251 (class 1255 OID 41416)
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
-- TOC entry 252 (class 1255 OID 41417)
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
-- TOC entry 219 (class 1259 OID 41418)
-- Name: accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accounts (
    id integer NOT NULL,
    user_id integer,
    account_number character varying(20) NOT NULL,
    balance numeric(15,2) DEFAULT 0.00,
    account_type character varying(50) DEFAULT 'debit'::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT accounts_account_type_check CHECK (((account_type)::text = ANY (ARRAY[('debit'::character varying)::text, ('credit'::character varying)::text, ('loan'::character varying)::text, ('bank_loan_fund'::character varying)::text])))
);


ALTER TABLE public.accounts OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 41427)
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
-- TOC entry 5180 (class 0 OID 0)
-- Dependencies: 220
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- TOC entry 221 (class 1259 OID 41428)
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
    CONSTRAINT chk_category CHECK (((category)::text = ANY (ARRAY[('mortgage'::character varying)::text, ('auto'::character varying)::text, ('electronics'::character varying)::text, ('personal'::character varying)::text]))),
    CONSTRAINT chk_rate CHECK (((annual_rate > (0)::numeric) AND (annual_rate < (100)::numeric))),
    CONSTRAINT chk_terms CHECK (((min_term_months > 0) AND (max_term_months >= min_term_months)))
);


ALTER TABLE public.loan_products OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 41448)
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
    CONSTRAINT chk_loan_status CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('closed'::character varying)::text, ('overdue'::character varying)::text, ('defaulted'::character varying)::text]))),
    CONSTRAINT chk_principal CHECK ((principal > (0)::numeric))
);


ALTER TABLE public.loans OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 41467)
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
-- TOC entry 224 (class 1259 OID 41480)
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
-- TOC entry 225 (class 1259 OID 41485)
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
-- TOC entry 226 (class 1259 OID 41506)
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
-- TOC entry 5181 (class 0 OID 0)
-- Dependencies: 226
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- TOC entry 227 (class 1259 OID 41507)
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
-- TOC entry 228 (class 1259 OID 41511)
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
-- TOC entry 5182 (class 0 OID 0)
-- Dependencies: 228
-- Name: loan_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_products_id_seq OWNED BY public.loan_products.id;


--
-- TOC entry 229 (class 1259 OID 41512)
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
    CONSTRAINT chk_schedule_status CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('paid'::character varying)::text, ('overdue'::character varying)::text, ('partially_paid'::character varying)::text])))
);


ALTER TABLE public.loan_schedule OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 41524)
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
-- TOC entry 5183 (class 0 OID 0)
-- Dependencies: 230
-- Name: loan_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_schedule_id_seq OWNED BY public.loan_schedule.id;


--
-- TOC entry 231 (class 1259 OID 41525)
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
-- TOC entry 232 (class 1259 OID 41530)
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
-- TOC entry 5184 (class 0 OID 0)
-- Dependencies: 232
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- TOC entry 233 (class 1259 OID 41531)
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
    CONSTRAINT transactions_transaction_type_check CHECK (((transaction_type)::text = ANY (ARRAY[('internal'::character varying)::text, ('external'::character varying)::text, ('loan_disbursement'::character varying)::text, ('loan_payment'::character varying)::text])))
);


ALTER TABLE public.transactions OWNER TO postgres;

--
-- TOC entry 234 (class 1259 OID 41543)
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
-- TOC entry 235 (class 1259 OID 41548)
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
-- TOC entry 5185 (class 0 OID 0)
-- Dependencies: 235
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- TOC entry 236 (class 1259 OID 41549)
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
-- TOC entry 237 (class 1259 OID 41554)
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
-- TOC entry 5186 (class 0 OID 0)
-- Dependencies: 237
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4911 (class 2604 OID 41555)
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- TOC entry 4928 (class 2604 OID 41556)
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- TOC entry 4915 (class 2604 OID 41557)
-- Name: loan_products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products ALTER COLUMN id SET DEFAULT nextval('public.loan_products_id_seq'::regclass);


--
-- TOC entry 4938 (class 2604 OID 41558)
-- Name: loan_schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule ALTER COLUMN id SET DEFAULT nextval('public.loan_schedule_id_seq'::regclass);


--
-- TOC entry 4919 (class 2604 OID 41559)
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- TOC entry 4940 (class 2604 OID 41560)
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- TOC entry 4923 (class 2604 OID 41561)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 5160 (class 0 OID 41418)
-- Dependencies: 219
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts (id, user_id, account_number, balance, account_type, created_at) FROM stdin;
1	1	40817810241179458708	3889.00	debit	2026-03-28 07:00:43.046755
2	1	40817810741953746212	1111.00	debit	2026-03-28 07:01:46.625811
\.


--
-- TOC entry 5165 (class 0 OID 41485)
-- Dependencies: 225
-- Data for Name: cards; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cards (id, account_id, card_number, card_holder_name, expiry_date, cvv_hash, card_type, card_brand, is_active, is_blocked, daily_limit, monthly_limit, pin_hash, failed_attempts, last_used_at, created_at, updated_at) FROM stdin;
1	1	4409 6564 3169 8321	КОНДРАШОВ ДАНИИЛ	2031-03-28	83eaf4dc5e19bcbeb23801e2c3e08c4a89cc82d0a42a903767f9c938d1deac4f	debit	visa	t	f	100000.00	500000.00	13b4088f2f9a285e22128d11a6a1a31254baf9936c0192655d32a7f563aad503	0	\N	2026-03-28 07:00:43.06697	2026-03-28 07:00:43.06697
2	2	5592 7686 2417 8369	КОНДРАШОВ ДАНИИЛ	2031-03-28	a77b6cbdf6fae1676369dea1e1ea675e4c2400c9e43bd535fdfd9395cb48cbaa	debit	mastercard	t	f	100000.00	500000.00	44e081556e1ae4a2bfed531a64dd185109c416e4248cec40ce28a7c272edafa9	0	\N	2026-03-28 07:01:46.629608	2026-03-28 07:01:46.629608
\.


--
-- TOC entry 5162 (class 0 OID 41428)
-- Dependencies: 221
-- Data for Name: loan_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_products (id, name, category, annual_rate, min_amount, max_amount, min_term_months, max_term_months, description, is_active, created_at) FROM stdin;
\.


--
-- TOC entry 5168 (class 0 OID 41512)
-- Dependencies: 229
-- Data for Name: loan_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_schedule (id, loan_id, payment_number, due_date, principal_part, interest_part, total_amount, status, paid_at, transaction_id) FROM stdin;
\.


--
-- TOC entry 5163 (class 0 OID 41448)
-- Dependencies: 222
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loans (id, user_id, product_id, target_account_id, bank_account_id, principal, annual_rate, term_months, monthly_payment, total_paid, remaining_balance, status, issued_at, next_payment_date, closed_at) FROM stdin;
\.


--
-- TOC entry 5171 (class 0 OID 41531)
-- Dependencies: 233
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transactions (id, from_account_id, to_account_id, amount, transaction_type, description, status, created_at) FROM stdin;
1	\N	1	5000.00	external	Пополнение счёта	completed	2026-03-28 07:00:57.995455
2	1	2	1111.00	internal		completed	2026-03-28 07:01:59.064235
\.


--
-- TOC entry 5164 (class 0 OID 41467)
-- Dependencies: 223
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, phone, password_hash, created_at, updated_at, first_name, last_name, middle_name, date_of_birth, passport_series, passport_number, address, primary_account_id, is_system_user) FROM stdin;
1	kondrashobdevs@gmail.com	+71112223344	32363dcb3726ef4801badd2d1d0ae00f:b288ac8fee2c57334084b9fd0b9e89663d56f4ffa8fd0486e067b7870e916e83	2026-03-28 06:59:44.524079	2026-03-28 06:59:44.524079	Даниил	Кондрашов	Владимирович	2002-01-19	5465	176583		1	f
\.


--
-- TOC entry 5187 (class 0 OID 0)
-- Dependencies: 220
-- Name: accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_id_seq', 2, true);


--
-- TOC entry 5188 (class 0 OID 0)
-- Dependencies: 226
-- Name: cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cards_id_seq', 2, true);


--
-- TOC entry 5189 (class 0 OID 0)
-- Dependencies: 228
-- Name: loan_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_products_id_seq', 1, false);


--
-- TOC entry 5190 (class 0 OID 0)
-- Dependencies: 230
-- Name: loan_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_schedule_id_seq', 1, false);


--
-- TOC entry 5191 (class 0 OID 0)
-- Dependencies: 232
-- Name: loans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loans_id_seq', 1, false);


--
-- TOC entry 5192 (class 0 OID 0)
-- Dependencies: 235
-- Name: transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_id_seq', 2, true);


--
-- TOC entry 5193 (class 0 OID 0)
-- Dependencies: 237
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 1, true);


--
-- TOC entry 4959 (class 2606 OID 41563)
-- Name: accounts accounts_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_account_number_key UNIQUE (account_number);


--
-- TOC entry 4961 (class 2606 OID 41565)
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 4977 (class 2606 OID 41567)
-- Name: cards cards_card_number_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_card_number_unique UNIQUE (card_number);


--
-- TOC entry 4979 (class 2606 OID 41569)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- TOC entry 4963 (class 2606 OID 41571)
-- Name: loan_products loan_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products
    ADD CONSTRAINT loan_products_pkey PRIMARY KEY (id);


--
-- TOC entry 4987 (class 2606 OID 41573)
-- Name: loan_schedule loan_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_pkey PRIMARY KEY (id);


--
-- TOC entry 4967 (class 2606 OID 41575)
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- TOC entry 4992 (class 2606 OID 41577)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 4971 (class 2606 OID 41579)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 4973 (class 2606 OID 41581)
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- TOC entry 4975 (class 2606 OID 41583)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 4980 (class 1259 OID 41584)
-- Name: idx_cards_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_account_id ON public.cards USING btree (account_id);


--
-- TOC entry 4981 (class 1259 OID 41585)
-- Name: idx_cards_card_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_card_number ON public.cards USING btree (card_number);


--
-- TOC entry 4982 (class 1259 OID 41586)
-- Name: idx_cards_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_is_active ON public.cards USING btree (is_active);


--
-- TOC entry 4964 (class 1259 OID 41587)
-- Name: idx_loans_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_status ON public.loans USING btree (status);


--
-- TOC entry 4965 (class 1259 OID 41588)
-- Name: idx_loans_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_user ON public.loans USING btree (user_id);


--
-- TOC entry 4983 (class 1259 OID 41589)
-- Name: idx_schedule_due; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_due ON public.loan_schedule USING btree (due_date);


--
-- TOC entry 4984 (class 1259 OID 41590)
-- Name: idx_schedule_loan; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_loan ON public.loan_schedule USING btree (loan_id);


--
-- TOC entry 4985 (class 1259 OID 41591)
-- Name: idx_schedule_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_status ON public.loan_schedule USING btree (status);


--
-- TOC entry 4988 (class 1259 OID 41592)
-- Name: idx_transactions_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_created ON public.transactions USING btree (created_at DESC);


--
-- TOC entry 4989 (class 1259 OID 41593)
-- Name: idx_transactions_from; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_from ON public.transactions USING btree (from_account_id);


--
-- TOC entry 4990 (class 1259 OID 41594)
-- Name: idx_transactions_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_to ON public.transactions USING btree (to_account_id);


--
-- TOC entry 4968 (class 1259 OID 41595)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- TOC entry 4969 (class 1259 OID 41596)
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- TOC entry 5158 (class 2618 OID 41597)
-- Name: active_loans_view protect_loan_delete; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE protect_loan_delete AS
    ON DELETE TO public.active_loans_view DO INSTEAD  UPDATE public.loans SET status = 'closed'::character varying, closed_at = CURRENT_TIMESTAMP
  WHERE (loans.id = old.loan_id);


--
-- TOC entry 5159 (class 2618 OID 41598)
-- Name: user_cards_view update_card_limits; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE update_card_limits AS
    ON UPDATE TO public.user_cards_view DO INSTEAD  UPDATE public.cards SET daily_limit = new.daily_limit, monthly_limit = new.monthly_limit
  WHERE (cards.id = old.card_id);


--
-- TOC entry 5004 (class 2620 OID 41599)
-- Name: cards check_card_number_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_card_number_validity BEFORE INSERT OR UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.validate_card_number_trigger();


--
-- TOC entry 5005 (class 2620 OID 41600)
-- Name: cards trigger_update_cards_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_cards_timestamp BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.update_cards_updated_at();


--
-- TOC entry 4993 (class 2606 OID 41601)
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 4999 (class 2606 OID 41606)
-- Name: cards cards_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- TOC entry 5000 (class 2606 OID 41611)
-- Name: loan_schedule loan_schedule_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- TOC entry 5001 (class 2606 OID 41616)
-- Name: loan_schedule loan_schedule_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 4994 (class 2606 OID 41621)
-- Name: loans loans_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4995 (class 2606 OID 41626)
-- Name: loans loans_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.loan_products(id);


--
-- TOC entry 4996 (class 2606 OID 41631)
-- Name: loans loans_target_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_target_account_id_fkey FOREIGN KEY (target_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4997 (class 2606 OID 41636)
-- Name: loans loans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5002 (class 2606 OID 41641)
-- Name: transactions transactions_from_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_from_account_id_fkey FOREIGN KEY (from_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5003 (class 2606 OID 41646)
-- Name: transactions transactions_to_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_to_account_id_fkey FOREIGN KEY (to_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 4998 (class 2606 OID 41651)
-- Name: users users_primary_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_primary_account_id_fkey FOREIGN KEY (primary_account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


-- Completed on 2026-05-02 14:16:53

--
-- PostgreSQL database dump complete
--

\unrestrict 70FRye9tUVwnFNxCm1Szn6tbgvZqBSwWGFFdgil3ejsj7NwBlemW0lpARbl87Bl


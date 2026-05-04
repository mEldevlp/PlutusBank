--
-- PostgreSQL database dump
--

\restrict I29pbrbk59IDR0EPTcRlaYIrLqnpIAQulYzCYJqML5KepyPhYJFCYpZ2NGT8MNi

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-05-03 19:33:35

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
-- TOC entry 5 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- TOC entry 5302 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 301 (class 1255 OID 49959)
-- Name: generate_crypto_address(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_crypto_address() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    addr VARCHAR;
    exists_check INT;
BEGIN
    LOOP
        addr := '0x' || encode(gen_random_bytes(20), 'hex');
        SELECT COUNT(*) INTO exists_check FROM crypto_wallets WHERE address = addr;
        IF exists_check = 0 THEN
            EXIT;
        END IF;
    END LOOP;
    RETURN addr;
END;
$$;


ALTER FUNCTION public.generate_crypto_address() OWNER TO postgres;

--
-- TOC entry 283 (class 1255 OID 49605)
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
-- TOC entry 284 (class 1255 OID 49606)
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
-- TOC entry 291 (class 1255 OID 49607)
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
-- TOC entry 298 (class 1255 OID 49608)
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
-- TOC entry 299 (class 1255 OID 49609)
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
-- TOC entry 220 (class 1259 OID 49610)
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
-- TOC entry 221 (class 1259 OID 49619)
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
-- TOC entry 5303 (class 0 OID 0)
-- Dependencies: 221
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- TOC entry 222 (class 1259 OID 49620)
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
-- TOC entry 223 (class 1259 OID 49640)
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
-- TOC entry 224 (class 1259 OID 49659)
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
-- TOC entry 225 (class 1259 OID 49672)
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
-- TOC entry 226 (class 1259 OID 49677)
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
-- TOC entry 227 (class 1259 OID 49698)
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
-- TOC entry 5304 (class 0 OID 0)
-- Dependencies: 227
-- Name: cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cards_id_seq OWNED BY public.cards.id;


--
-- TOC entry 247 (class 1259 OID 50005)
-- Name: crypto_price_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crypto_price_history (
    id bigint NOT NULL,
    currency_id integer NOT NULL,
    price numeric(20,8) NOT NULL,
    recorded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.crypto_price_history OWNER TO postgres;

--
-- TOC entry 246 (class 1259 OID 50004)
-- Name: crypto_price_history_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crypto_price_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crypto_price_history_id_seq OWNER TO postgres;

--
-- TOC entry 5305 (class 0 OID 0)
-- Dependencies: 246
-- Name: crypto_price_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.crypto_price_history_id_seq OWNED BY public.crypto_price_history.id;


--
-- TOC entry 244 (class 1259 OID 49912)
-- Name: crypto_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crypto_transactions (
    id integer NOT NULL,
    operation_type character varying(16) NOT NULL,
    user_id integer NOT NULL,
    counterparty_user_id integer,
    currency_id integer NOT NULL,
    coin_amount numeric(28,8) NOT NULL,
    rub_amount numeric(15,2),
    price_per_coin numeric(20,8),
    card_id integer,
    related_account_id integer,
    bank_transaction_id integer,
    description character varying(255) DEFAULT ''::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_coin_amount_pos CHECK ((coin_amount > (0)::numeric)),
    CONSTRAINT chk_crypto_op_type CHECK (((operation_type)::text = ANY ((ARRAY['buy'::character varying, 'sell'::character varying, 'transfer_in'::character varying, 'transfer_out'::character varying])::text[])))
);


ALTER TABLE public.crypto_transactions OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 49911)
-- Name: crypto_transactions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crypto_transactions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crypto_transactions_id_seq OWNER TO postgres;

--
-- TOC entry 5306 (class 0 OID 0)
-- Dependencies: 243
-- Name: crypto_transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.crypto_transactions_id_seq OWNED BY public.crypto_transactions.id;


--
-- TOC entry 242 (class 1259 OID 49881)
-- Name: crypto_wallets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.crypto_wallets (
    id integer NOT NULL,
    user_id integer NOT NULL,
    currency_id integer NOT NULL,
    balance numeric(28,8) DEFAULT 0 NOT NULL,
    address character varying(42) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_balance_nonneg CHECK ((balance >= (0)::numeric))
);


ALTER TABLE public.crypto_wallets OWNER TO postgres;

--
-- TOC entry 241 (class 1259 OID 49880)
-- Name: crypto_wallets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.crypto_wallets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.crypto_wallets_id_seq OWNER TO postgres;

--
-- TOC entry 5307 (class 0 OID 0)
-- Dependencies: 241
-- Name: crypto_wallets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.crypto_wallets_id_seq OWNED BY public.crypto_wallets.id;


--
-- TOC entry 240 (class 1259 OID 49849)
-- Name: cryptocurrencies; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cryptocurrencies (
    id integer NOT NULL,
    symbol character varying(8) NOT NULL,
    name character varying(64) NOT NULL,
    description text DEFAULT ''::text,
    icon_color character varying(7) DEFAULT '#20a9bc'::character varying,
    icon_letter character varying(2) DEFAULT '?'::character varying,
    base_price numeric(20,8) NOT NULL,
    current_price numeric(20,8) NOT NULL,
    volatility numeric(8,5) DEFAULT 0.01 NOT NULL,
    jump_intensity numeric(8,5) DEFAULT 0.05 NOT NULL,
    jump_sigma numeric(8,5) DEFAULT 0.05 NOT NULL,
    drift numeric(8,5) DEFAULT 0.0 NOT NULL,
    mean_reversion numeric(8,5) DEFAULT 0.02 NOT NULL,
    last_updated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    is_active boolean DEFAULT true,
    CONSTRAINT chk_crypto_prices CHECK (((base_price > (0)::numeric) AND (current_price > (0)::numeric)))
);


ALTER TABLE public.cryptocurrencies OWNER TO postgres;

--
-- TOC entry 239 (class 1259 OID 49848)
-- Name: cryptocurrencies_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cryptocurrencies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cryptocurrencies_id_seq OWNER TO postgres;

--
-- TOC entry 5308 (class 0 OID 0)
-- Dependencies: 239
-- Name: cryptocurrencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cryptocurrencies_id_seq OWNED BY public.cryptocurrencies.id;


--
-- TOC entry 228 (class 1259 OID 49699)
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
-- TOC entry 229 (class 1259 OID 49703)
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
-- TOC entry 5309 (class 0 OID 0)
-- Dependencies: 229
-- Name: loan_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_products_id_seq OWNED BY public.loan_products.id;


--
-- TOC entry 230 (class 1259 OID 49704)
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
-- TOC entry 231 (class 1259 OID 49716)
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
-- TOC entry 5310 (class 0 OID 0)
-- Dependencies: 231
-- Name: loan_schedule_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loan_schedule_id_seq OWNED BY public.loan_schedule.id;


--
-- TOC entry 232 (class 1259 OID 49717)
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
-- TOC entry 233 (class 1259 OID 49722)
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
-- TOC entry 5311 (class 0 OID 0)
-- Dependencies: 233
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- TOC entry 234 (class 1259 OID 49723)
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
-- TOC entry 235 (class 1259 OID 49735)
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
-- TOC entry 236 (class 1259 OID 49740)
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
-- TOC entry 5312 (class 0 OID 0)
-- Dependencies: 236
-- Name: transactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.transactions_id_seq OWNED BY public.transactions.id;


--
-- TOC entry 237 (class 1259 OID 49741)
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
-- TOC entry 245 (class 1259 OID 49960)
-- Name: user_wallets_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.user_wallets_view AS
 SELECT w.id AS wallet_id,
    w.user_id,
    w.address,
    c.id AS currency_id,
    c.symbol,
    c.name,
    c.icon_color,
    c.icon_letter,
    c.current_price,
    w.balance,
    ((w.balance * c.current_price))::numeric(20,2) AS rub_value
   FROM (public.crypto_wallets w
     JOIN public.cryptocurrencies c ON ((c.id = w.currency_id)));


ALTER VIEW public.user_wallets_view OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 49746)
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
-- TOC entry 5313 (class 0 OID 0)
-- Dependencies: 238
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4974 (class 2604 OID 49747)
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- TOC entry 4991 (class 2604 OID 49748)
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- TOC entry 5024 (class 2604 OID 50008)
-- Name: crypto_price_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_price_history ALTER COLUMN id SET DEFAULT nextval('public.crypto_price_history_id_seq'::regclass);


--
-- TOC entry 5021 (class 2604 OID 49915)
-- Name: crypto_transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions ALTER COLUMN id SET DEFAULT nextval('public.crypto_transactions_id_seq'::regclass);


--
-- TOC entry 5018 (class 2604 OID 49884)
-- Name: crypto_wallets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets ALTER COLUMN id SET DEFAULT nextval('public.crypto_wallets_id_seq'::regclass);


--
-- TOC entry 5007 (class 2604 OID 49852)
-- Name: cryptocurrencies id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cryptocurrencies ALTER COLUMN id SET DEFAULT nextval('public.cryptocurrencies_id_seq'::regclass);


--
-- TOC entry 4978 (class 2604 OID 49749)
-- Name: loan_products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products ALTER COLUMN id SET DEFAULT nextval('public.loan_products_id_seq'::regclass);


--
-- TOC entry 5001 (class 2604 OID 49750)
-- Name: loan_schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule ALTER COLUMN id SET DEFAULT nextval('public.loan_schedule_id_seq'::regclass);


--
-- TOC entry 4982 (class 2604 OID 49751)
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- TOC entry 5003 (class 2604 OID 49752)
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- TOC entry 4986 (class 2604 OID 49753)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 5275 (class 0 OID 49610)
-- Dependencies: 220
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts (id, user_id, account_number, balance, account_type, created_at) FROM stdin;
2	1	40817810741953746212	1111.00	debit	2026-03-28 07:01:46.625811
1	1	40817810241179458708	20188.46	debit	2026-03-28 07:00:43.046755
3	2	40817810000000000001	100000949.92	bank_loan_fund	2026-05-02 16:48:25.629555
\.


--
-- TOC entry 5280 (class 0 OID 49677)
-- Dependencies: 226
-- Data for Name: cards; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cards (id, account_id, card_number, card_holder_name, expiry_date, cvv_hash, card_type, card_brand, is_active, is_blocked, daily_limit, monthly_limit, pin_hash, failed_attempts, last_used_at, created_at, updated_at) FROM stdin;
1	1	4409 6564 3169 8321	КОНДРАШОВ ДАНИИЛ	2031-03-28	83eaf4dc5e19bcbeb23801e2c3e08c4a89cc82d0a42a903767f9c938d1deac4f	debit	visa	t	f	100000.00	500000.00	13b4088f2f9a285e22128d11a6a1a31254baf9936c0192655d32a7f563aad503	0	\N	2026-03-28 07:00:43.06697	2026-03-28 07:00:43.06697
2	2	5592 7686 2417 8369	КОНДРАШОВ ДАНИИЛ	2031-03-28	a77b6cbdf6fae1676369dea1e1ea675e4c2400c9e43bd535fdfd9395cb48cbaa	debit	mastercard	t	f	100000.00	500000.00	44e081556e1ae4a2bfed531a64dd185109c416e4248cec40ce28a7c272edafa9	0	\N	2026-03-28 07:01:46.629608	2026-03-28 07:01:46.629608
\.


--
-- TOC entry 5296 (class 0 OID 50005)
-- Dependencies: 247
-- Data for Name: crypto_price_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crypto_price_history (id, currency_id, price, recorded_at) FROM stdin;
1	1	1501.10232659	2026-05-03 14:54:53.172924
2	2	679.74911194	2026-05-03 14:54:53.172924
3	3	5485.00418774	2026-05-03 14:54:53.172924
4	4	27.48025475	2026-05-03 14:54:53.172924
5	1	1459.80818812	2026-05-03 14:48:53.172924
6	2	681.83317488	2026-05-03 14:48:53.172924
7	3	5590.96920819	2026-05-03 14:48:53.172924
8	4	29.82534996	2026-05-03 14:48:53.172924
9	1	1514.12644969	2026-05-03 14:42:53.172924
10	2	752.54227004	2026-05-03 14:42:53.172924
11	3	4614.54804500	2026-05-03 14:42:53.172924
12	4	30.81253833	2026-05-03 14:42:53.172924
13	1	1515.86263215	2026-05-03 14:36:53.172924
14	2	693.58188007	2026-05-03 14:36:53.172924
15	3	4751.29168886	2026-05-03 14:36:53.172924
16	4	20.73088007	2026-05-03 14:36:53.172924
17	1	1445.65111725	2026-05-03 14:30:53.172924
18	2	703.26894179	2026-05-03 14:30:53.172924
19	3	5832.61273694	2026-05-03 14:30:53.172924
20	4	29.00413649	2026-05-03 14:30:53.172924
21	1	1500.20161023	2026-05-03 14:24:53.172924
22	2	734.21445234	2026-05-03 14:24:53.172924
23	3	5540.10812387	2026-05-03 14:24:53.172924
24	4	22.29134643	2026-05-03 14:24:53.172924
25	1	1481.75944624	2026-05-03 14:18:53.172924
26	2	696.33846686	2026-05-03 14:18:53.172924
27	3	5480.53247773	2026-05-03 14:18:53.172924
28	4	31.75962760	2026-05-03 14:18:53.172924
29	1	1469.79843397	2026-05-03 14:12:53.172924
30	2	686.61122587	2026-05-03 14:12:53.172924
31	3	5851.43172782	2026-05-03 14:12:53.172924
32	4	26.23584891	2026-05-03 14:12:53.172924
33	1	1469.12915995	2026-05-03 14:06:53.172924
34	2	762.58154981	2026-05-03 14:06:53.172924
35	3	5823.33583966	2026-05-03 14:06:53.172924
36	4	27.50329301	2026-05-03 14:06:53.172924
37	1	1487.25053711	2026-05-03 14:00:53.172924
38	2	729.28737620	2026-05-03 14:00:53.172924
39	3	5843.65673083	2026-05-03 14:00:53.172924
40	4	22.69914811	2026-05-03 14:00:53.172924
41	1	1473.23071210	2026-05-03 13:54:53.172924
42	2	772.13360198	2026-05-03 13:54:53.172924
43	3	4844.68504789	2026-05-03 13:54:53.172924
44	4	27.40196035	2026-05-03 13:54:53.172924
45	1	1504.42970815	2026-05-03 13:48:53.172924
46	2	723.68695786	2026-05-03 13:48:53.172924
47	3	5397.94441917	2026-05-03 13:48:53.172924
48	4	31.58466057	2026-05-03 13:48:53.172924
49	1	1514.45490006	2026-05-03 13:42:53.172924
50	2	766.69928809	2026-05-03 13:42:53.172924
51	3	5252.37601004	2026-05-03 13:42:53.172924
52	4	29.93445881	2026-05-03 13:42:53.172924
53	1	1491.75093951	2026-05-03 13:36:53.172924
54	2	764.66021808	2026-05-03 13:36:53.172924
55	3	5595.71247470	2026-05-03 13:36:53.172924
56	4	28.11798548	2026-05-03 13:36:53.172924
57	1	1444.26614671	2026-05-03 13:30:53.172924
58	2	760.24859069	2026-05-03 13:30:53.172924
59	3	4943.67351302	2026-05-03 13:30:53.172924
60	4	22.24472344	2026-05-03 13:30:53.172924
61	1	1493.81260697	2026-05-03 13:24:53.172924
62	2	715.56056735	2026-05-03 13:24:53.172924
63	3	5591.23900922	2026-05-03 13:24:53.172924
64	4	22.44146112	2026-05-03 13:24:53.172924
65	1	1445.63123667	2026-05-03 13:18:53.172924
66	2	750.20458204	2026-05-03 13:18:53.172924
67	3	5256.28864731	2026-05-03 13:18:53.172924
68	4	31.30714893	2026-05-03 13:18:53.172924
69	1	1458.04497838	2026-05-03 13:12:53.172924
70	2	713.37804137	2026-05-03 13:12:53.172924
71	3	5417.32318923	2026-05-03 13:12:53.172924
72	4	25.75872443	2026-05-03 13:12:53.172924
73	1	1483.38729254	2026-05-03 13:06:53.172924
74	2	752.75863655	2026-05-03 13:06:53.172924
75	3	5821.51734807	2026-05-03 13:06:53.172924
76	4	26.31020859	2026-05-03 13:06:53.172924
77	1	1495.98966442	2026-05-03 13:00:53.172924
78	2	719.48038792	2026-05-03 13:00:53.172924
79	3	5897.35268126	2026-05-03 13:00:53.172924
80	4	23.16376126	2026-05-03 13:00:53.172924
81	1	1459.79914720	2026-05-03 12:54:53.172924
82	2	680.14482856	2026-05-03 12:54:53.172924
83	3	5624.89941297	2026-05-03 12:54:53.172924
84	4	29.03543722	2026-05-03 12:54:53.172924
85	1	1450.66186423	2026-05-03 12:48:53.172924
86	2	773.33466447	2026-05-03 12:48:53.172924
87	3	5738.36289062	2026-05-03 12:48:53.172924
88	4	32.49471909	2026-05-03 12:48:53.172924
89	1	1470.99782675	2026-05-03 12:42:53.172924
90	2	758.10193214	2026-05-03 12:42:53.172924
91	3	5189.04358398	2026-05-03 12:42:53.172924
92	4	32.83060091	2026-05-03 12:42:53.172924
93	1	1502.76522369	2026-05-03 12:36:53.172924
94	2	730.98155841	2026-05-03 12:36:53.172924
95	3	5506.95774013	2026-05-03 12:36:53.172924
96	4	23.72213884	2026-05-03 12:36:53.172924
97	1	1471.76978752	2026-05-03 12:30:53.172924
98	2	769.32311381	2026-05-03 12:30:53.172924
99	3	5149.18366402	2026-05-03 12:30:53.172924
100	4	25.84819468	2026-05-03 12:30:53.172924
101	1	1444.78613470	2026-05-03 12:24:53.172924
102	2	680.70797501	2026-05-03 12:24:53.172924
103	3	5666.56892602	2026-05-03 12:24:53.172924
104	4	27.48268310	2026-05-03 12:24:53.172924
105	1	1491.11513385	2026-05-03 12:18:53.172924
106	2	692.36162742	2026-05-03 12:18:53.172924
107	3	5831.44666863	2026-05-03 12:18:53.172924
108	4	22.72176880	2026-05-03 12:18:53.172924
109	1	1498.12181004	2026-05-03 12:12:53.172924
110	2	710.54115052	2026-05-03 12:12:53.172924
111	3	5854.27265495	2026-05-03 12:12:53.172924
112	4	26.85289770	2026-05-03 12:12:53.172924
113	1	1454.32867130	2026-05-03 12:06:53.172924
114	2	708.95422362	2026-05-03 12:06:53.172924
115	3	5345.94328504	2026-05-03 12:06:53.172924
116	4	28.25543220	2026-05-03 12:06:53.172924
117	1	1465.60215031	2026-05-03 12:00:53.172924
118	2	723.79541458	2026-05-03 12:00:53.172924
119	3	5928.95016065	2026-05-03 12:00:53.172924
120	4	33.21338394	2026-05-03 12:00:53.172924
121	1	1496.64191392	2026-05-03 11:54:53.172924
122	2	710.55554623	2026-05-03 11:54:53.172924
123	3	5942.99480271	2026-05-03 11:54:53.172924
124	4	29.48074115	2026-05-03 11:54:53.172924
125	1	1504.56550500	2026-05-03 11:48:53.172924
126	2	754.62280754	2026-05-03 11:48:53.172924
127	3	5217.34862452	2026-05-03 11:48:53.172924
128	4	25.52998009	2026-05-03 11:48:53.172924
129	1	1451.20898236	2026-05-03 11:42:53.172924
130	2	776.85302836	2026-05-03 11:42:53.172924
131	3	5195.28851938	2026-05-03 11:42:53.172924
132	4	32.69338530	2026-05-03 11:42:53.172924
133	1	1457.56235071	2026-05-03 11:36:53.172924
134	2	744.53657942	2026-05-03 11:36:53.172924
135	3	5289.98336272	2026-05-03 11:36:53.172924
136	4	25.47843980	2026-05-03 11:36:53.172924
137	1	1478.78918869	2026-05-03 11:30:53.172924
138	2	744.65825800	2026-05-03 11:30:53.172924
139	3	5847.77391567	2026-05-03 11:30:53.172924
140	4	29.75103859	2026-05-03 11:30:53.172924
141	1	1478.73333532	2026-05-03 11:24:53.172924
142	2	709.94556685	2026-05-03 11:24:53.172924
143	3	4918.63525467	2026-05-03 11:24:53.172924
144	4	32.07572456	2026-05-03 11:24:53.172924
145	1	1512.00741553	2026-05-03 11:18:53.172924
146	2	686.75182736	2026-05-03 11:18:53.172924
147	3	5548.75120841	2026-05-03 11:18:53.172924
148	4	33.78507842	2026-05-03 11:18:53.172924
149	1	1512.53789335	2026-05-03 11:12:53.172924
150	2	772.87977636	2026-05-03 11:12:53.172924
151	3	5575.42510986	2026-05-03 11:12:53.172924
152	4	34.69053058	2026-05-03 11:12:53.172924
153	1	1500.05577111	2026-05-03 11:06:53.172924
154	2	708.67974795	2026-05-03 11:06:53.172924
155	3	5473.69992558	2026-05-03 11:06:53.172924
156	4	34.64040518	2026-05-03 11:06:53.172924
157	1	1484.08337283	2026-05-03 11:00:53.172924
158	2	785.76385323	2026-05-03 11:00:53.172924
159	3	5334.32792908	2026-05-03 11:00:53.172924
160	4	34.12722402	2026-05-03 11:00:53.172924
161	1	1468.32179859	2026-05-03 10:54:53.172924
162	2	704.86689743	2026-05-03 10:54:53.172924
163	3	5166.93380294	2026-05-03 10:54:53.172924
164	4	29.62801851	2026-05-03 10:54:53.172924
165	1	1516.06977348	2026-05-03 10:48:53.172924
166	2	739.31176223	2026-05-03 10:48:53.172924
167	3	5816.60702931	2026-05-03 10:48:53.172924
168	4	30.37267990	2026-05-03 10:48:53.172924
169	1	1468.95098480	2026-05-03 10:42:53.172924
170	2	705.40983320	2026-05-03 10:42:53.172924
171	3	5056.80599750	2026-05-03 10:42:53.172924
172	4	33.74483106	2026-05-03 10:42:53.172924
173	1	1500.16415159	2026-05-03 10:36:53.172924
174	2	720.90950524	2026-05-03 10:36:53.172924
175	3	5798.00836051	2026-05-03 10:36:53.172924
176	4	28.68285506	2026-05-03 10:36:53.172924
177	1	1461.73191999	2026-05-03 10:30:53.172924
178	2	780.43040502	2026-05-03 10:30:53.172924
179	3	5081.63119125	2026-05-03 10:30:53.172924
180	4	34.88770042	2026-05-03 10:30:53.172924
181	1	1456.79204185	2026-05-03 10:24:53.172924
182	2	747.85840214	2026-05-03 10:24:53.172924
183	3	5953.76342881	2026-05-03 10:24:53.172924
184	4	34.96407060	2026-05-03 10:24:53.172924
185	1	1470.44765873	2026-05-03 10:18:53.172924
186	2	782.36686131	2026-05-03 10:18:53.172924
187	3	5091.53568139	2026-05-03 10:18:53.172924
188	4	32.44555391	2026-05-03 10:18:53.172924
189	1	1524.98701395	2026-05-03 10:12:53.172924
190	2	726.11052724	2026-05-03 10:12:53.172924
191	3	6048.29351260	2026-05-03 10:12:53.172924
192	4	29.02177355	2026-05-03 10:12:53.172924
193	1	1457.49338527	2026-05-03 10:06:53.172924
194	2	779.96648223	2026-05-03 10:06:53.172924
195	3	6075.31251634	2026-05-03 10:06:53.172924
196	4	30.48787881	2026-05-03 10:06:53.172924
197	1	1487.57183335	2026-05-03 10:00:53.172924
198	2	739.28351269	2026-05-03 10:00:53.172924
199	3	5142.51738547	2026-05-03 10:00:53.172924
200	4	35.09420718	2026-05-03 10:00:53.172924
201	1	1526.38232133	2026-05-03 09:54:53.172924
202	2	785.45312435	2026-05-03 09:54:53.172924
203	3	5557.06846623	2026-05-03 09:54:53.172924
204	4	24.78605662	2026-05-03 09:54:53.172924
205	1	1518.73298681	2026-05-03 09:48:53.172924
206	2	750.44886479	2026-05-03 09:48:53.172924
207	3	5261.29987846	2026-05-03 09:48:53.172924
208	4	24.34686201	2026-05-03 09:48:53.172924
209	1	1462.90548160	2026-05-03 09:42:53.172924
210	2	735.65144362	2026-05-03 09:42:53.172924
211	3	5785.59902224	2026-05-03 09:42:53.172924
212	4	27.47917227	2026-05-03 09:42:53.172924
213	1	1482.10774312	2026-05-03 09:36:53.172924
214	2	711.84917408	2026-05-03 09:36:53.172924
215	3	5275.24940765	2026-05-03 09:36:53.172924
216	4	31.88251700	2026-05-03 09:36:53.172924
217	1	1500.45410674	2026-05-03 09:30:53.172924
218	2	722.72294034	2026-05-03 09:30:53.172924
219	3	4906.15094835	2026-05-03 09:30:53.172924
220	4	28.96898794	2026-05-03 09:30:53.172924
221	1	1524.54378854	2026-05-03 09:24:53.172924
222	2	723.03291911	2026-05-03 09:24:53.172924
223	3	5699.19618398	2026-05-03 09:24:53.172924
224	4	23.94340495	2026-05-03 09:24:53.172924
225	1	1484.35643702	2026-05-03 09:18:53.172924
226	2	726.12683979	2026-05-03 09:18:53.172924
227	3	6094.65044837	2026-05-03 09:18:53.172924
228	4	23.51667991	2026-05-03 09:18:53.172924
229	1	1502.21639670	2026-05-03 09:12:53.172924
230	2	752.48773097	2026-05-03 09:12:53.172924
231	3	6111.82229609	2026-05-03 09:12:53.172924
232	4	31.19486644	2026-05-03 09:12:53.172924
233	1	1535.23361166	2026-05-03 09:06:53.172924
234	2	717.76484324	2026-05-03 09:06:53.172924
235	3	6029.66923603	2026-05-03 09:06:53.172924
236	4	30.88968773	2026-05-03 09:06:53.172924
237	1	1453.29449682	2026-05-03 09:00:53.172924
238	2	713.24364872	2026-05-03 09:00:53.172924
239	3	4914.01048980	2026-05-03 09:00:53.172924
240	4	25.46567634	2026-05-03 09:00:53.172924
241	1	1453.97784599	2026-05-03 08:54:53.172924
242	2	751.15416142	2026-05-03 08:54:53.172924
243	3	5597.15844881	2026-05-03 08:54:53.172924
244	4	28.32149071	2026-05-03 08:54:53.172924
245	1	1490.88294417	2026-05-03 08:48:53.172924
246	2	732.79909966	2026-05-03 08:48:53.172924
247	3	5457.35096318	2026-05-03 08:48:53.172924
248	4	32.28014173	2026-05-03 08:48:53.172924
249	1	1499.25735354	2026-05-03 08:42:53.172924
250	2	763.51705174	2026-05-03 08:42:53.172924
251	3	5628.35623977	2026-05-03 08:42:53.172924
252	4	23.87694817	2026-05-03 08:42:53.172924
253	1	1502.94958971	2026-05-03 08:36:53.172924
254	2	699.43295359	2026-05-03 08:36:53.172924
255	3	5268.65269533	2026-05-03 08:36:53.172924
256	4	35.42503947	2026-05-03 08:36:53.172924
257	1	1450.87869979	2026-05-03 08:30:53.172924
258	2	790.27926763	2026-05-03 08:30:53.172924
259	3	5913.45779241	2026-05-03 08:30:53.172924
260	4	35.81970572	2026-05-03 08:30:53.172924
261	1	1496.20960095	2026-05-03 08:24:53.172924
262	2	792.18406981	2026-05-03 08:24:53.172924
263	3	5869.48558560	2026-05-03 08:24:53.172924
264	4	27.78213277	2026-05-03 08:24:53.172924
265	1	1519.08212344	2026-05-03 08:18:53.172924
266	2	725.55165495	2026-05-03 08:18:53.172924
267	3	5876.51399964	2026-05-03 08:18:53.172924
268	4	30.37875029	2026-05-03 08:18:53.172924
269	1	1470.29676335	2026-05-03 08:12:53.172924
270	2	777.03670227	2026-05-03 08:12:53.172924
271	3	5000.80511870	2026-05-03 08:12:53.172924
272	4	30.73309205	2026-05-03 08:12:53.172924
273	1	1493.74477378	2026-05-03 08:06:53.172924
274	2	691.53079431	2026-05-03 08:06:53.172924
275	3	4957.18258920	2026-05-03 08:06:53.172924
276	4	32.40538080	2026-05-03 08:06:53.172924
277	1	1533.89089310	2026-05-03 08:00:53.172924
278	2	766.29733596	2026-05-03 08:00:53.172924
279	3	5884.37563676	2026-05-03 08:00:53.172924
280	4	26.77365560	2026-05-03 08:00:53.172924
281	1	1508.52822862	2026-05-03 07:54:53.172924
282	2	776.74650864	2026-05-03 07:54:53.172924
283	3	5818.95700752	2026-05-03 07:54:53.172924
284	4	30.39930585	2026-05-03 07:54:53.172924
285	1	1466.25085103	2026-05-03 07:48:53.172924
286	2	759.58372683	2026-05-03 07:48:53.172924
287	3	5037.64349437	2026-05-03 07:48:53.172924
288	4	35.60340636	2026-05-03 07:48:53.172924
289	1	1506.42239907	2026-05-03 07:42:53.172924
290	2	761.41788846	2026-05-03 07:42:53.172924
291	3	5369.55316204	2026-05-03 07:42:53.172924
292	4	24.76224419	2026-05-03 07:42:53.172924
293	1	1481.55434471	2026-05-03 07:36:53.172924
294	2	782.27207538	2026-05-03 07:36:53.172924
295	3	5589.04137459	2026-05-03 07:36:53.172924
296	4	32.87966315	2026-05-03 07:36:53.172924
297	1	1478.88677151	2026-05-03 07:30:53.172924
298	2	750.54150895	2026-05-03 07:30:53.172924
299	3	5006.97837224	2026-05-03 07:30:53.172924
300	4	26.31893537	2026-05-03 07:30:53.172924
301	1	1495.07834093	2026-05-03 07:24:53.172924
302	2	777.47836352	2026-05-03 07:24:53.172924
303	3	5582.56033141	2026-05-03 07:24:53.172924
304	4	26.65714169	2026-05-03 07:24:53.172924
305	1	1518.98810543	2026-05-03 07:18:53.172924
306	2	761.43609106	2026-05-03 07:18:53.172924
307	3	5180.53149588	2026-05-03 07:18:53.172924
308	4	28.98271174	2026-05-03 07:18:53.172924
309	1	1525.43884893	2026-05-03 07:12:53.172924
310	2	731.33245302	2026-05-03 07:12:53.172924
311	3	5714.95949725	2026-05-03 07:12:53.172924
312	4	30.01005280	2026-05-03 07:12:53.172924
313	1	1472.22827600	2026-05-03 07:06:53.172924
314	2	719.66252672	2026-05-03 07:06:53.172924
315	3	5950.63868204	2026-05-03 07:06:53.172924
316	4	33.54290164	2026-05-03 07:06:53.172924
317	1	1486.39068623	2026-05-03 07:00:53.172924
318	2	719.63001987	2026-05-03 07:00:53.172924
319	3	5219.61061453	2026-05-03 07:00:53.172924
320	4	24.76629463	2026-05-03 07:00:53.172924
321	1	1473.57796798	2026-05-03 06:54:53.172924
322	2	726.39947319	2026-05-03 06:54:53.172924
323	3	6054.00201935	2026-05-03 06:54:53.172924
324	4	31.17396085	2026-05-03 06:54:53.172924
325	1	1449.70546685	2026-05-03 06:48:53.172924
326	2	721.85610246	2026-05-03 06:48:53.172924
327	3	5483.94188156	2026-05-03 06:48:53.172924
328	4	32.29088096	2026-05-03 06:48:53.172924
329	1	1532.35992382	2026-05-03 06:42:53.172924
330	2	736.96265636	2026-05-03 06:42:53.172924
331	3	5015.01184099	2026-05-03 06:42:53.172924
332	4	30.42945411	2026-05-03 06:42:53.172924
333	1	1467.25376687	2026-05-03 06:36:53.172924
334	2	734.13571925	2026-05-03 06:36:53.172924
335	3	5140.21693539	2026-05-03 06:36:53.172924
336	4	31.01372968	2026-05-03 06:36:53.172924
337	1	1527.39412750	2026-05-03 06:30:53.172924
338	2	767.86588785	2026-05-03 06:30:53.172924
339	3	6019.29756107	2026-05-03 06:30:53.172924
340	4	32.37646463	2026-05-03 06:30:53.172924
341	1	1497.63911622	2026-05-03 06:24:53.172924
342	2	760.98034782	2026-05-03 06:24:53.172924
343	3	5397.53323902	2026-05-03 06:24:53.172924
344	4	34.00101978	2026-05-03 06:24:53.172924
345	1	1495.84514183	2026-05-03 06:18:53.172924
346	2	739.27596989	2026-05-03 06:18:53.172924
347	3	5580.91435636	2026-05-03 06:18:53.172924
348	4	26.92267793	2026-05-03 06:18:53.172924
349	1	1522.09340646	2026-05-03 06:12:53.172924
350	2	750.39716618	2026-05-03 06:12:53.172924
351	3	6038.55969627	2026-05-03 06:12:53.172924
352	4	29.46065757	2026-05-03 06:12:53.172924
353	1	1496.81621616	2026-05-03 06:06:53.172924
354	2	775.06395971	2026-05-03 06:06:53.172924
355	3	5618.23765389	2026-05-03 06:06:53.172924
356	4	24.51305578	2026-05-03 06:06:53.172924
357	1	1529.10866891	2026-05-03 06:00:53.172924
358	2	692.21667239	2026-05-03 06:00:53.172924
359	3	5551.12092475	2026-05-03 06:00:53.172924
360	4	33.21883467	2026-05-03 06:00:53.172924
361	1	1518.78286250	2026-05-03 05:54:53.172924
362	2	727.21256652	2026-05-03 05:54:53.172924
363	3	4957.67069379	2026-05-03 05:54:53.172924
364	4	29.59073465	2026-05-03 05:54:53.172924
365	1	1471.36079516	2026-05-03 05:48:53.172924
366	2	688.71740553	2026-05-03 05:48:53.172924
367	3	5810.82295782	2026-05-03 05:48:53.172924
368	4	30.69951076	2026-05-03 05:48:53.172924
369	1	1518.06863334	2026-05-03 05:42:53.172924
370	2	708.96855276	2026-05-03 05:42:53.172924
371	3	5868.21979778	2026-05-03 05:42:53.172924
372	4	24.84173312	2026-05-03 05:42:53.172924
373	1	1443.72198878	2026-05-03 05:36:53.172924
374	2	736.85518392	2026-05-03 05:36:53.172924
375	3	5479.43118693	2026-05-03 05:36:53.172924
376	4	24.67043010	2026-05-03 05:36:53.172924
377	1	1445.34846345	2026-05-03 05:30:53.172924
378	2	713.08919608	2026-05-03 05:30:53.172924
379	3	5766.92692865	2026-05-03 05:30:53.172924
380	4	30.98327142	2026-05-03 05:30:53.172924
381	1	1489.93383089	2026-05-03 05:24:53.172924
382	2	687.16386336	2026-05-03 05:24:53.172924
383	3	4843.55682788	2026-05-03 05:24:53.172924
384	4	29.97057456	2026-05-03 05:24:53.172924
385	1	1506.79532778	2026-05-03 05:18:53.172924
386	2	748.66552638	2026-05-03 05:18:53.172924
387	3	5194.78397876	2026-05-03 05:18:53.172924
388	4	33.28050747	2026-05-03 05:18:53.172924
389	1	1515.56997803	2026-05-03 05:12:53.172924
390	2	764.33113815	2026-05-03 05:12:53.172924
391	3	5067.60162322	2026-05-03 05:12:53.172924
392	4	26.45317099	2026-05-03 05:12:53.172924
393	1	1454.69893013	2026-05-03 05:06:53.172924
394	2	708.13752120	2026-05-03 05:06:53.172924
395	3	4967.67700464	2026-05-03 05:06:53.172924
396	4	27.81883763	2026-05-03 05:06:53.172924
397	1	1507.89313031	2026-05-03 05:00:53.172924
398	2	718.11005971	2026-05-03 05:00:53.172924
399	3	5519.67354505	2026-05-03 05:00:53.172924
400	4	25.10587100	2026-05-03 05:00:53.172924
401	1	1511.95045979	2026-05-03 04:54:53.172924
402	2	714.51746014	2026-05-03 04:54:53.172924
403	3	5605.46295778	2026-05-03 04:54:53.172924
404	4	22.12201516	2026-05-03 04:54:53.172924
405	1	1514.32150930	2026-05-03 04:48:53.172924
406	2	772.53459350	2026-05-03 04:48:53.172924
407	3	5238.32207083	2026-05-03 04:48:53.172924
408	4	27.22682209	2026-05-03 04:48:53.172924
409	1	1520.85457387	2026-05-03 04:42:53.172924
410	2	700.52007312	2026-05-03 04:42:53.172924
411	3	4917.82006671	2026-05-03 04:42:53.172924
412	4	30.61442335	2026-05-03 04:42:53.172924
413	1	1497.80546085	2026-05-03 04:36:53.172924
414	2	744.22702575	2026-05-03 04:36:53.172924
415	3	4835.06585698	2026-05-03 04:36:53.172924
416	4	30.82692515	2026-05-03 04:36:53.172924
417	1	1458.51587155	2026-05-03 04:30:53.172924
418	2	694.54908052	2026-05-03 04:30:53.172924
419	3	4992.53670845	2026-05-03 04:30:53.172924
420	4	31.47183564	2026-05-03 04:30:53.172924
421	1	1510.96601471	2026-05-03 04:24:53.172924
422	2	703.97288371	2026-05-03 04:24:53.172924
423	3	4956.03194840	2026-05-03 04:24:53.172924
424	4	21.42284935	2026-05-03 04:24:53.172924
425	1	1466.24175555	2026-05-03 04:18:53.172924
426	2	697.36272023	2026-05-03 04:18:53.172924
427	3	5436.40024502	2026-05-03 04:18:53.172924
428	4	33.01848659	2026-05-03 04:18:53.172924
429	1	1480.29758971	2026-05-03 04:12:53.172924
430	2	735.82718779	2026-05-03 04:12:53.172924
431	3	5075.01702977	2026-05-03 04:12:53.172924
432	4	32.10000687	2026-05-03 04:12:53.172924
433	1	1457.40388832	2026-05-03 04:06:53.172924
434	2	691.40115911	2026-05-03 04:06:53.172924
435	3	5174.63010054	2026-05-03 04:06:53.172924
436	4	32.48884099	2026-05-03 04:06:53.172924
437	1	1497.63976669	2026-05-03 04:00:53.172924
438	2	751.33750740	2026-05-03 04:00:53.172924
439	3	5518.40355947	2026-05-03 04:00:53.172924
440	4	21.60296235	2026-05-03 04:00:53.172924
441	1	1497.84175635	2026-05-03 03:54:53.172924
442	2	742.11030698	2026-05-03 03:54:53.172924
443	3	4693.94347535	2026-05-03 03:54:53.172924
444	4	25.95246836	2026-05-03 03:54:53.172924
445	1	1484.59220623	2026-05-03 03:48:53.172924
446	2	719.47879272	2026-05-03 03:48:53.172924
447	3	5866.96599391	2026-05-03 03:48:53.172924
448	4	25.96379758	2026-05-03 03:48:53.172924
449	1	1441.16044242	2026-05-03 03:42:53.172924
450	2	759.80297613	2026-05-03 03:42:53.172924
451	3	5610.06239594	2026-05-03 03:42:53.172924
452	4	29.09050274	2026-05-03 03:42:53.172924
453	1	1463.97594705	2026-05-03 03:36:53.172924
454	2	725.31968959	2026-05-03 03:36:53.172924
455	3	5409.14004930	2026-05-03 03:36:53.172924
456	4	22.52019325	2026-05-03 03:36:53.172924
457	1	1441.70909479	2026-05-03 03:30:53.172924
458	2	720.12445188	2026-05-03 03:30:53.172924
459	3	4868.42211900	2026-05-03 03:30:53.172924
460	4	26.57627070	2026-05-03 03:30:53.172924
461	1	1434.93885941	2026-05-03 03:24:53.172924
462	2	666.89749705	2026-05-03 03:24:53.172924
463	3	5563.79047319	2026-05-03 03:24:53.172924
464	4	32.79835695	2026-05-03 03:24:53.172924
465	1	1484.70727140	2026-05-03 03:18:53.172924
466	2	688.18815587	2026-05-03 03:18:53.172924
467	3	5593.79057579	2026-05-03 03:18:53.172924
468	4	22.93488924	2026-05-03 03:18:53.172924
469	1	1486.25275586	2026-05-03 03:12:53.172924
470	2	712.58850384	2026-05-03 03:12:53.172924
471	3	5110.80088738	2026-05-03 03:12:53.172924
472	4	31.32630018	2026-05-03 03:12:53.172924
473	1	1458.71988507	2026-05-03 03:06:53.172924
474	2	692.02816442	2026-05-03 03:06:53.172924
475	3	4975.90548688	2026-05-03 03:06:53.172924
476	4	22.03245760	2026-05-03 03:06:53.172924
477	1	1455.36785234	2026-05-03 03:00:53.172924
478	2	748.58110095	2026-05-03 03:00:53.172924
479	3	4768.77277750	2026-05-03 03:00:53.172924
480	4	29.39121974	2026-05-03 03:00:53.172924
481	1	1436.93360661	2026-05-03 02:54:53.172924
482	2	761.65353613	2026-05-03 02:54:53.172924
483	3	5729.95492961	2026-05-03 02:54:53.172924
484	4	22.05261766	2026-05-03 02:54:53.172924
485	1	1496.61008785	2026-05-03 02:48:53.172924
486	2	763.56173317	2026-05-03 02:48:53.172924
487	3	5287.54620795	2026-05-03 02:48:53.172924
488	4	25.62598241	2026-05-03 02:48:53.172924
489	1	1494.85542502	2026-05-03 02:42:53.172924
490	2	708.28167150	2026-05-03 02:42:53.172924
491	3	5570.90174668	2026-05-03 02:42:53.172924
492	4	21.52861953	2026-05-03 02:42:53.172924
493	1	1430.91057448	2026-05-03 02:36:53.172924
494	2	756.28272048	2026-05-03 02:36:53.172924
495	3	5128.94462138	2026-05-03 02:36:53.172924
496	4	23.01121095	2026-05-03 02:36:53.172924
497	1	1465.32214653	2026-05-03 02:30:53.172924
498	2	692.20959538	2026-05-03 02:30:53.172924
499	3	5478.79973818	2026-05-03 02:30:53.172924
500	4	28.49312101	2026-05-03 02:30:53.172924
501	1	1429.76899160	2026-05-03 02:24:53.172924
502	2	684.25360941	2026-05-03 02:24:53.172924
503	3	5562.93850190	2026-05-03 02:24:53.172924
504	4	28.76994395	2026-05-03 02:24:53.172924
505	1	1501.22346034	2026-05-03 02:18:53.172924
506	2	738.79920032	2026-05-03 02:18:53.172924
507	3	5671.96111862	2026-05-03 02:18:53.172924
508	4	31.76671764	2026-05-03 02:18:53.172924
509	1	1473.26489924	2026-05-03 02:12:53.172924
510	2	755.31987646	2026-05-03 02:12:53.172924
511	3	4950.49925249	2026-05-03 02:12:53.172924
512	4	22.09255047	2026-05-03 02:12:53.172924
513	1	1483.83273715	2026-05-03 02:06:53.172924
514	2	680.15986573	2026-05-03 02:06:53.172924
515	3	4978.78251790	2026-05-03 02:06:53.172924
516	4	21.36686833	2026-05-03 02:06:53.172924
517	1	1452.89583478	2026-05-03 02:00:53.172924
518	2	696.95278389	2026-05-03 02:00:53.172924
519	3	5039.92524420	2026-05-03 02:00:53.172924
520	4	29.76156352	2026-05-03 02:00:53.172924
521	1	1480.64947263	2026-05-03 01:54:53.172924
522	2	753.89902814	2026-05-03 01:54:53.172924
523	3	5296.89599836	2026-05-03 01:54:53.172924
524	4	25.61839369	2026-05-03 01:54:53.172924
525	1	1507.30661938	2026-05-03 01:48:53.172924
526	2	717.36603701	2026-05-03 01:48:53.172924
527	3	5553.25062917	2026-05-03 01:48:53.172924
528	4	19.98527520	2026-05-03 01:48:53.172924
529	1	1445.58875072	2026-05-03 01:42:53.172924
530	2	664.09968987	2026-05-03 01:42:53.172924
531	3	4888.59139136	2026-05-03 01:42:53.172924
532	4	30.71820619	2026-05-03 01:42:53.172924
533	1	1419.88432432	2026-05-03 01:36:53.172924
534	2	661.84085508	2026-05-03 01:36:53.172924
535	3	5626.00807029	2026-05-03 01:36:53.172924
536	4	26.37069826	2026-05-03 01:36:53.172924
537	1	1423.30734182	2026-05-03 01:30:53.172924
538	2	719.99492519	2026-05-03 01:30:53.172924
539	3	5228.23787570	2026-05-03 01:30:53.172924
540	4	26.23430887	2026-05-03 01:30:53.172924
541	1	1429.03858901	2026-05-03 01:24:53.172924
542	2	743.41972133	2026-05-03 01:24:53.172924
543	3	5478.15045395	2026-05-03 01:24:53.172924
544	4	27.77438973	2026-05-03 01:24:53.172924
545	1	1434.35149658	2026-05-03 01:18:53.172924
546	2	685.78089782	2026-05-03 01:18:53.172924
547	3	5320.15212347	2026-05-03 01:18:53.172924
548	4	25.55828279	2026-05-03 01:18:53.172924
549	1	1443.45740793	2026-05-03 01:12:53.172924
550	2	656.02438762	2026-05-03 01:12:53.172924
551	3	4474.81536907	2026-05-03 01:12:53.172924
552	4	23.61278901	2026-05-03 01:12:53.172924
553	1	1479.38660190	2026-05-03 01:06:53.172924
554	2	652.89000656	2026-05-03 01:06:53.172924
555	3	5496.52700100	2026-05-03 01:06:53.172924
556	4	24.34608470	2026-05-03 01:06:53.172924
557	1	1434.86484036	2026-05-03 01:00:53.172924
558	2	735.18488978	2026-05-03 01:00:53.172924
559	3	5634.33991620	2026-05-03 01:00:53.172924
560	4	26.00369891	2026-05-03 01:00:53.172924
561	1	1462.47289248	2026-05-03 00:54:53.172924
562	2	731.74188169	2026-05-03 00:54:53.172924
563	3	4673.05208593	2026-05-03 00:54:53.172924
564	4	28.82508021	2026-05-03 00:54:53.172924
565	1	1442.23750075	2026-05-03 00:48:53.172924
566	2	729.37783178	2026-05-03 00:48:53.172924
567	3	4502.81651761	2026-05-03 00:48:53.172924
568	4	26.79420084	2026-05-03 00:48:53.172924
569	1	1475.41892801	2026-05-03 00:42:53.172924
570	2	748.21148647	2026-05-03 00:42:53.172924
571	3	5637.79153781	2026-05-03 00:42:53.172924
572	4	18.83753984	2026-05-03 00:42:53.172924
573	1	1434.33097385	2026-05-03 00:36:53.172924
574	2	741.02012414	2026-05-03 00:36:53.172924
575	3	5105.11513681	2026-05-03 00:36:53.172924
576	4	21.35627741	2026-05-03 00:36:53.172924
577	1	1499.18444207	2026-05-03 00:30:53.172924
578	2	722.95120713	2026-05-03 00:30:53.172924
579	3	5527.82450035	2026-05-03 00:30:53.172924
580	4	18.72749278	2026-05-03 00:30:53.172924
581	1	1492.41400084	2026-05-03 00:24:53.172924
582	2	726.43794069	2026-05-03 00:24:53.172924
583	3	5132.45351518	2026-05-03 00:24:53.172924
584	4	23.99576107	2026-05-03 00:24:53.172924
585	1	1416.61003856	2026-05-03 00:18:53.172924
586	2	694.81070144	2026-05-03 00:18:53.172924
587	3	5036.49723551	2026-05-03 00:18:53.172924
588	4	26.77346245	2026-05-03 00:18:53.172924
589	1	1466.96510701	2026-05-03 00:12:53.172924
590	2	694.50026465	2026-05-03 00:12:53.172924
591	3	4814.25879295	2026-05-03 00:12:53.172924
592	4	30.61343310	2026-05-03 00:12:53.172924
593	1	1484.77199025	2026-05-03 00:06:53.172924
594	2	694.94810852	2026-05-03 00:06:53.172924
595	3	5166.18649107	2026-05-03 00:06:53.172924
596	4	19.83725706	2026-05-03 00:06:53.172924
597	1	1476.44139318	2026-05-03 00:00:53.172924
598	2	689.59321556	2026-05-03 00:00:53.172924
599	3	4506.31744128	2026-05-03 00:00:53.172924
600	4	26.41233221	2026-05-03 00:00:53.172924
601	1	1422.78583638	2026-05-02 23:54:53.172924
602	2	706.53680961	2026-05-02 23:54:53.172924
603	3	5070.23222999	2026-05-02 23:54:53.172924
604	4	29.35945609	2026-05-02 23:54:53.172924
605	1	1450.04994411	2026-05-02 23:48:53.172924
606	2	676.63413847	2026-05-02 23:48:53.172924
607	3	4877.11303012	2026-05-02 23:48:53.172924
608	4	29.73061227	2026-05-02 23:48:53.172924
609	1	1494.94659735	2026-05-02 23:42:53.172924
610	2	670.07335640	2026-05-02 23:42:53.172924
611	3	5295.36523867	2026-05-02 23:42:53.172924
612	4	21.68122166	2026-05-02 23:42:53.172924
613	1	1472.86119511	2026-05-02 23:36:53.172924
614	2	663.21471859	2026-05-02 23:36:53.172924
615	3	5258.63613958	2026-05-02 23:36:53.172924
616	4	27.28120017	2026-05-02 23:36:53.172924
617	1	1420.83770672	2026-05-02 23:30:53.172924
618	2	666.44323727	2026-05-02 23:30:53.172924
619	3	5029.38142583	2026-05-02 23:30:53.172924
620	4	23.01723875	2026-05-02 23:30:53.172924
621	1	1475.70000849	2026-05-02 23:24:53.172924
622	2	676.09921994	2026-05-02 23:24:53.172924
623	3	4687.75988757	2026-05-02 23:24:53.172924
624	4	28.11265628	2026-05-02 23:24:53.172924
625	1	1452.88691253	2026-05-02 23:18:53.172924
626	2	688.44870717	2026-05-02 23:18:53.172924
627	3	4425.57043840	2026-05-02 23:18:53.172924
628	4	18.93751735	2026-05-02 23:18:53.172924
629	1	1441.35765257	2026-05-02 23:12:53.172924
630	2	679.36908990	2026-05-02 23:12:53.172924
631	3	5529.77687230	2026-05-02 23:12:53.172924
632	4	29.59163329	2026-05-02 23:12:53.172924
633	1	1461.40175666	2026-05-02 23:06:53.172924
634	2	733.40389555	2026-05-02 23:06:53.172924
635	3	4745.08869170	2026-05-02 23:06:53.172924
636	4	20.66317526	2026-05-02 23:06:53.172924
637	1	1436.20833167	2026-05-02 23:00:53.172924
638	2	696.28229700	2026-05-02 23:00:53.172924
639	3	4695.49411469	2026-05-02 23:00:53.172924
640	4	25.91765918	2026-05-02 23:00:53.172924
641	1	1493.85149320	2026-05-02 22:54:53.172924
642	2	654.75587721	2026-05-02 22:54:53.172924
643	3	5088.14642603	2026-05-02 22:54:53.172924
644	4	24.99106201	2026-05-02 22:54:53.172924
645	1	1442.71648128	2026-05-02 22:48:53.172924
646	2	665.04893563	2026-05-02 22:48:53.172924
647	3	5524.32963485	2026-05-02 22:48:53.172924
648	4	24.07989295	2026-05-02 22:48:53.172924
649	1	1480.00590578	2026-05-02 22:42:53.172924
650	2	677.43911976	2026-05-02 22:42:53.172924
651	3	4738.80307415	2026-05-02 22:42:53.172924
652	4	20.51449030	2026-05-02 22:42:53.172924
653	1	1449.84268583	2026-05-02 22:36:53.172924
654	2	699.37147367	2026-05-02 22:36:53.172924
655	3	5238.13475781	2026-05-02 22:36:53.172924
656	4	21.65135388	2026-05-02 22:36:53.172924
657	1	1473.14417212	2026-05-02 22:30:53.172924
658	2	716.40861852	2026-05-02 22:30:53.172924
659	3	4870.08602686	2026-05-02 22:30:53.172924
660	4	28.00573996	2026-05-02 22:30:53.172924
661	1	1483.02390322	2026-05-02 22:24:53.172924
662	2	655.57502623	2026-05-02 22:24:53.172924
663	3	5035.28679724	2026-05-02 22:24:53.172924
664	4	17.54023655	2026-05-02 22:24:53.172924
665	1	1486.27507644	2026-05-02 22:18:53.172924
666	2	730.48153383	2026-05-02 22:18:53.172924
667	3	5314.47358431	2026-05-02 22:18:53.172924
668	4	24.94083159	2026-05-02 22:18:53.172924
669	1	1408.53076846	2026-05-02 22:12:53.172924
670	2	650.94348212	2026-05-02 22:12:53.172924
671	3	5150.35744300	2026-05-02 22:12:53.172924
672	4	28.57317265	2026-05-02 22:12:53.172924
673	1	1490.18906552	2026-05-02 22:06:53.172924
674	2	734.80655244	2026-05-02 22:06:53.172924
675	3	4391.64702733	2026-05-02 22:06:53.172924
676	4	29.38077613	2026-05-02 22:06:53.172924
677	1	1449.46622626	2026-05-02 22:00:53.172924
678	2	692.40482601	2026-05-02 22:00:53.172924
679	3	4609.24657500	2026-05-02 22:00:53.172924
680	4	22.92043732	2026-05-02 22:00:53.172924
681	1	1456.13489076	2026-05-02 21:54:53.172924
682	2	713.43637994	2026-05-02 21:54:53.172924
683	3	5388.46037215	2026-05-02 21:54:53.172924
684	4	27.28768232	2026-05-02 21:54:53.172924
685	1	1436.50516140	2026-05-02 21:48:53.172924
686	2	677.11042988	2026-05-02 21:48:53.172924
687	3	4689.48279535	2026-05-02 21:48:53.172924
688	4	29.81066172	2026-05-02 21:48:53.172924
689	1	1432.62808786	2026-05-02 21:42:53.172924
690	2	639.20204228	2026-05-02 21:42:53.172924
691	3	5380.31928458	2026-05-02 21:42:53.172924
692	4	22.66339147	2026-05-02 21:42:53.172924
693	1	1443.82197034	2026-05-02 21:36:53.172924
694	2	670.98926941	2026-05-02 21:36:53.172924
695	3	4388.55786690	2026-05-02 21:36:53.172924
696	4	26.01336570	2026-05-02 21:36:53.172924
697	1	1409.07323160	2026-05-02 21:30:53.172924
698	2	707.89174046	2026-05-02 21:30:53.172924
699	3	4913.46538981	2026-05-02 21:30:53.172924
700	4	21.80267346	2026-05-02 21:30:53.172924
701	1	1408.80625235	2026-05-02 21:24:53.172924
702	2	640.84278717	2026-05-02 21:24:53.172924
703	3	4685.87726351	2026-05-02 21:24:53.172924
704	4	19.65792657	2026-05-02 21:24:53.172924
705	1	1424.48954526	2026-05-02 21:18:53.172924
706	2	665.38818556	2026-05-02 21:18:53.172924
707	3	5436.00531899	2026-05-02 21:18:53.172924
708	4	18.61107679	2026-05-02 21:18:53.172924
709	1	1464.83203308	2026-05-02 21:12:53.172924
710	2	707.55265982	2026-05-02 21:12:53.172924
711	3	4983.85416690	2026-05-02 21:12:53.172924
712	4	26.04668989	2026-05-02 21:12:53.172924
713	1	1477.01533217	2026-05-02 21:06:53.172924
714	2	700.66661070	2026-05-02 21:06:53.172924
715	3	4396.38050734	2026-05-02 21:06:53.172924
716	4	17.88492572	2026-05-02 21:06:53.172924
717	1	1456.32367084	2026-05-02 21:00:53.172924
718	2	697.94259062	2026-05-02 21:00:53.172924
719	3	5509.50645465	2026-05-02 21:00:53.172924
720	4	23.17144461	2026-05-02 21:00:53.172924
721	1	1455.84731888	2026-05-02 20:54:53.172924
722	2	700.38776448	2026-05-02 20:54:53.172924
723	3	4364.33892229	2026-05-02 20:54:53.172924
724	4	17.93522460	2026-05-02 20:54:53.172924
725	1	1428.48122603	2026-05-02 20:48:53.172924
726	2	687.47602071	2026-05-02 20:48:53.172924
727	3	5007.90062496	2026-05-02 20:48:53.172924
728	4	17.30577734	2026-05-02 20:48:53.172924
729	1	1444.41199239	2026-05-02 20:42:53.172924
730	2	733.35203994	2026-05-02 20:42:53.172924
731	3	4329.01844571	2026-05-02 20:42:53.172924
732	4	27.63080514	2026-05-02 20:42:53.172924
733	1	1478.82989615	2026-05-02 20:36:53.172924
734	2	722.86473783	2026-05-02 20:36:53.172924
735	3	4994.37268368	2026-05-02 20:36:53.172924
736	4	21.30038139	2026-05-02 20:36:53.172924
737	1	1447.67732908	2026-05-02 20:30:53.172924
738	2	658.89330703	2026-05-02 20:30:53.172924
739	3	4404.24727048	2026-05-02 20:30:53.172924
740	4	25.67620446	2026-05-02 20:30:53.172924
741	1	1486.61433594	2026-05-02 20:24:53.172924
742	2	658.15783590	2026-05-02 20:24:53.172924
743	3	4299.37891503	2026-05-02 20:24:53.172924
744	4	19.24008278	2026-05-02 20:24:53.172924
745	1	1478.72067692	2026-05-02 20:18:53.172924
746	2	697.11689569	2026-05-02 20:18:53.172924
747	3	5048.61192360	2026-05-02 20:18:53.172924
748	4	22.77100348	2026-05-02 20:18:53.172924
749	1	1461.32183583	2026-05-02 20:12:53.172924
750	2	660.75297740	2026-05-02 20:12:53.172924
751	3	4283.83497876	2026-05-02 20:12:53.172924
752	4	23.04306272	2026-05-02 20:12:53.172924
753	1	1451.14976870	2026-05-02 20:06:53.172924
754	2	691.06885894	2026-05-02 20:06:53.172924
755	3	4395.14471227	2026-05-02 20:06:53.172924
756	4	26.74860522	2026-05-02 20:06:53.172924
757	1	1472.93506718	2026-05-02 20:00:53.172924
758	2	684.25368254	2026-05-02 20:00:53.172924
759	3	5295.87796270	2026-05-02 20:00:53.172924
760	4	24.69040776	2026-05-02 20:00:53.172924
761	1	1468.39636618	2026-05-02 19:54:53.172924
762	2	681.57981643	2026-05-02 19:54:53.172924
763	3	4540.68504440	2026-05-02 19:54:53.172924
764	4	28.85098584	2026-05-02 19:54:53.172924
765	1	1471.84518661	2026-05-02 19:48:53.172924
766	2	731.07775089	2026-05-02 19:48:53.172924
767	3	4398.45724510	2026-05-02 19:48:53.172924
768	4	26.41336390	2026-05-02 19:48:53.172924
769	1	1408.11662122	2026-05-02 19:42:53.172924
770	2	668.26385464	2026-05-02 19:42:53.172924
771	3	4912.08002712	2026-05-02 19:42:53.172924
772	4	23.59753160	2026-05-02 19:42:53.172924
773	1	1451.27161566	2026-05-02 19:36:53.172924
774	2	673.18042690	2026-05-02 19:36:53.172924
775	3	5038.58183676	2026-05-02 19:36:53.172924
776	4	25.45284272	2026-05-02 19:36:53.172924
777	1	1491.96753289	2026-05-02 19:30:53.172924
778	2	694.06584599	2026-05-02 19:30:53.172924
779	3	5451.38140420	2026-05-02 19:30:53.172924
780	4	29.39614626	2026-05-02 19:30:53.172924
781	1	1436.74786124	2026-05-02 19:24:53.172924
782	2	664.45897298	2026-05-02 19:24:53.172924
783	3	4770.41299382	2026-05-02 19:24:53.172924
784	4	22.40719458	2026-05-02 19:24:53.172924
785	1	1474.81729475	2026-05-02 19:18:53.172924
786	2	717.74304780	2026-05-02 19:18:53.172924
787	3	4465.48595062	2026-05-02 19:18:53.172924
788	4	20.30624046	2026-05-02 19:18:53.172924
789	1	1430.85162183	2026-05-02 19:12:53.172924
790	2	742.14800745	2026-05-02 19:12:53.172924
791	3	4811.38397839	2026-05-02 19:12:53.172924
792	4	27.43389384	2026-05-02 19:12:53.172924
793	1	1469.44478235	2026-05-02 19:06:53.172924
794	2	736.19264156	2026-05-02 19:06:53.172924
795	3	5534.31968174	2026-05-02 19:06:53.172924
796	4	18.57677925	2026-05-02 19:06:53.172924
797	1	1459.38991893	2026-05-02 19:00:53.172924
798	2	728.92643510	2026-05-02 19:00:53.172924
799	3	5423.47175761	2026-05-02 19:00:53.172924
800	4	27.35916132	2026-05-02 19:00:53.172924
801	1	1439.28198490	2026-05-02 18:54:53.172924
802	2	693.61218071	2026-05-02 18:54:53.172924
803	3	4989.36534865	2026-05-02 18:54:53.172924
804	4	27.30029740	2026-05-02 18:54:53.172924
805	1	1481.43108823	2026-05-02 18:48:53.172924
806	2	708.84894065	2026-05-02 18:48:53.172924
807	3	5221.59236311	2026-05-02 18:48:53.172924
808	4	20.85448787	2026-05-02 18:48:53.172924
809	1	1410.49270623	2026-05-02 18:42:53.172924
810	2	642.93966583	2026-05-02 18:42:53.172924
811	3	4981.90018527	2026-05-02 18:42:53.172924
812	4	22.95861961	2026-05-02 18:42:53.172924
813	1	1484.94789017	2026-05-02 18:36:53.172924
814	2	738.71321372	2026-05-02 18:36:53.172924
815	3	5266.72648994	2026-05-02 18:36:53.172924
816	4	24.84699582	2026-05-02 18:36:53.172924
817	1	1417.55523735	2026-05-02 18:30:53.172924
818	2	653.27941645	2026-05-02 18:30:53.172924
819	3	4969.76805303	2026-05-02 18:30:53.172924
820	4	22.88920109	2026-05-02 18:30:53.172924
821	1	1450.85094314	2026-05-02 18:24:53.172924
822	2	698.25480568	2026-05-02 18:24:53.172924
823	3	5396.98365743	2026-05-02 18:24:53.172924
824	4	21.15514441	2026-05-02 18:24:53.172924
825	1	1452.42859136	2026-05-02 18:18:53.172924
826	2	741.75589977	2026-05-02 18:18:53.172924
827	3	4629.44377296	2026-05-02 18:18:53.172924
828	4	22.78093474	2026-05-02 18:18:53.172924
829	1	1459.09805909	2026-05-02 18:12:53.172924
830	2	667.94229051	2026-05-02 18:12:53.172924
831	3	4398.52457637	2026-05-02 18:12:53.172924
832	4	20.91326384	2026-05-02 18:12:53.172924
833	1	1443.92346627	2026-05-02 18:06:53.172924
834	2	705.10261740	2026-05-02 18:06:53.172924
835	3	5563.42474462	2026-05-02 18:06:53.172924
836	4	30.31841229	2026-05-02 18:06:53.172924
837	1	1440.76364225	2026-05-02 18:00:53.172924
838	2	740.23823041	2026-05-02 18:00:53.172924
839	3	5419.78247531	2026-05-02 18:00:53.172924
840	4	18.66008568	2026-05-02 18:00:53.172924
841	1	1457.13489930	2026-05-02 17:54:53.172924
842	2	672.61954282	2026-05-02 17:54:53.172924
843	3	4420.68825819	2026-05-02 17:54:53.172924
844	4	22.13754715	2026-05-02 17:54:53.172924
845	1	1437.02607498	2026-05-02 17:48:53.172924
846	2	686.61681858	2026-05-02 17:48:53.172924
847	3	4945.24882842	2026-05-02 17:48:53.172924
848	4	25.27829604	2026-05-02 17:48:53.172924
849	1	1412.69874555	2026-05-02 17:42:53.172924
850	2	690.83136884	2026-05-02 17:42:53.172924
851	3	4814.13602205	2026-05-02 17:42:53.172924
852	4	28.91344241	2026-05-02 17:42:53.172924
853	1	1446.66958048	2026-05-02 17:36:53.172924
854	2	650.46511283	2026-05-02 17:36:53.172924
855	3	4972.40241923	2026-05-02 17:36:53.172924
856	4	24.30094920	2026-05-02 17:36:53.172924
857	1	1449.86666298	2026-05-02 17:30:53.172924
858	2	749.33655836	2026-05-02 17:30:53.172924
859	3	5350.40116890	2026-05-02 17:30:53.172924
860	4	28.50691073	2026-05-02 17:30:53.172924
861	1	1473.20861672	2026-05-02 17:24:53.172924
862	2	718.75250078	2026-05-02 17:24:53.172924
863	3	4855.38265268	2026-05-02 17:24:53.172924
864	4	18.75439663	2026-05-02 17:24:53.172924
865	1	1437.96728819	2026-05-02 17:18:53.172924
866	2	699.44551289	2026-05-02 17:18:53.172924
867	3	4905.73866229	2026-05-02 17:18:53.172924
868	4	19.32713621	2026-05-02 17:18:53.172924
869	1	1485.34609611	2026-05-02 17:12:53.172924
870	2	684.30393471	2026-05-02 17:12:53.172924
871	3	4476.69469349	2026-05-02 17:12:53.172924
872	4	28.22445794	2026-05-02 17:12:53.172924
873	1	1453.72537448	2026-05-02 17:06:53.172924
874	2	722.28769344	2026-05-02 17:06:53.172924
875	3	4974.99178816	2026-05-02 17:06:53.172924
876	4	29.53102188	2026-05-02 17:06:53.172924
877	1	1425.10106359	2026-05-02 17:00:53.172924
878	2	686.99963017	2026-05-02 17:00:53.172924
879	3	4732.96776812	2026-05-02 17:00:53.172924
880	4	21.83748898	2026-05-02 17:00:53.172924
881	1	1487.45257079	2026-05-02 16:54:53.172924
882	2	689.56816596	2026-05-02 16:54:53.172924
883	3	5330.38566049	2026-05-02 16:54:53.172924
884	4	26.23194638	2026-05-02 16:54:53.172924
885	1	1461.91682717	2026-05-02 16:48:53.172924
886	2	700.05085739	2026-05-02 16:48:53.172924
887	3	5275.07581991	2026-05-02 16:48:53.172924
888	4	27.87766254	2026-05-02 16:48:53.172924
889	1	1436.30158049	2026-05-02 16:42:53.172924
890	2	726.45507008	2026-05-02 16:42:53.172924
891	3	5396.00004706	2026-05-02 16:42:53.172924
892	4	26.64021268	2026-05-02 16:42:53.172924
893	1	1435.64712965	2026-05-02 16:36:53.172924
894	2	755.54066140	2026-05-02 16:36:53.172924
895	3	5546.06168674	2026-05-02 16:36:53.172924
896	4	22.78444209	2026-05-02 16:36:53.172924
897	1	1484.14044021	2026-05-02 16:30:53.172924
898	2	702.91508535	2026-05-02 16:30:53.172924
899	3	5140.76562023	2026-05-02 16:30:53.172924
900	4	29.76779692	2026-05-02 16:30:53.172924
901	1	1480.18331861	2026-05-02 16:24:53.172924
902	2	679.88644815	2026-05-02 16:24:53.172924
903	3	5026.43866827	2026-05-02 16:24:53.172924
904	4	26.61917270	2026-05-02 16:24:53.172924
905	1	1491.37918742	2026-05-02 16:18:53.172924
906	2	661.89127030	2026-05-02 16:18:53.172924
907	3	5125.17085145	2026-05-02 16:18:53.172924
908	4	29.47715633	2026-05-02 16:18:53.172924
909	1	1497.60107833	2026-05-02 16:12:53.172924
910	2	740.60481808	2026-05-02 16:12:53.172924
911	3	5587.11785956	2026-05-02 16:12:53.172924
912	4	19.87695663	2026-05-02 16:12:53.172924
913	1	1464.52578297	2026-05-02 16:06:53.172924
914	2	711.61408945	2026-05-02 16:06:53.172924
915	3	5620.11572119	2026-05-02 16:06:53.172924
916	4	29.06760847	2026-05-02 16:06:53.172924
917	1	1451.85479175	2026-05-02 16:00:53.172924
918	2	745.06643465	2026-05-02 16:00:53.172924
919	3	4560.31452045	2026-05-02 16:00:53.172924
920	4	28.94528926	2026-05-02 16:00:53.172924
921	1	1443.46206394	2026-05-02 15:54:53.172924
922	2	669.23130398	2026-05-02 15:54:53.172924
923	3	5250.49963875	2026-05-02 15:54:53.172924
924	4	27.21379288	2026-05-02 15:54:53.172924
925	1	1457.78110963	2026-05-02 15:48:53.172924
926	2	660.66727373	2026-05-02 15:48:53.172924
927	3	5466.64196393	2026-05-02 15:48:53.172924
928	4	28.37348247	2026-05-02 15:48:53.172924
929	1	1428.87174156	2026-05-02 15:42:53.172924
930	2	718.42624814	2026-05-02 15:42:53.172924
931	3	5425.13046071	2026-05-02 15:42:53.172924
932	4	26.69098299	2026-05-02 15:42:53.172924
933	1	1508.91449965	2026-05-02 15:36:53.172924
934	2	713.34838671	2026-05-02 15:36:53.172924
935	3	4834.51807138	2026-05-02 15:36:53.172924
936	4	21.98564256	2026-05-02 15:36:53.172924
937	1	1505.65400640	2026-05-02 15:30:53.172924
938	2	688.85899762	2026-05-02 15:30:53.172924
939	3	4558.88083791	2026-05-02 15:30:53.172924
940	4	30.72928806	2026-05-02 15:30:53.172924
941	1	1472.44644686	2026-05-02 15:24:53.172924
942	2	696.95731144	2026-05-02 15:24:53.172924
943	3	4652.16700139	2026-05-02 15:24:53.172924
944	4	28.58701106	2026-05-02 15:24:53.172924
945	1	1451.82825580	2026-05-02 15:18:53.172924
946	2	722.86067030	2026-05-02 15:18:53.172924
947	3	4977.16625228	2026-05-02 15:18:53.172924
948	4	25.90349011	2026-05-02 15:18:53.172924
949	1	1476.17726352	2026-05-02 15:12:53.172924
950	2	709.05326435	2026-05-02 15:12:53.172924
951	3	4869.47806627	2026-05-02 15:12:53.172924
952	4	30.03756490	2026-05-02 15:12:53.172924
953	1	1510.14204742	2026-05-02 15:06:53.172924
954	2	735.42755460	2026-05-02 15:06:53.172924
955	3	4766.87287493	2026-05-02 15:06:53.172924
956	4	20.85815226	2026-05-02 15:06:53.172924
957	1	1502.55379640	2026-05-02 15:00:53.172924
958	2	750.04498593	2026-05-02 15:00:53.172924
959	3	4746.61985791	2026-05-02 15:00:53.172924
960	4	31.39971315	2026-05-02 15:00:53.172924
961	1	1470.52764005	2026-05-03 15:00:53.172924
962	2	715.56752017	2026-05-03 15:00:53.172924
963	3	5212.05482276	2026-05-03 15:00:53.172924
964	4	26.59959296	2026-05-03 15:00:53.172924
\.


--
-- TOC entry 5294 (class 0 OID 49912)
-- Dependencies: 244
-- Data for Name: crypto_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crypto_transactions (id, operation_type, user_id, counterparty_user_id, currency_id, coin_amount, rub_amount, price_per_coin, card_id, related_account_id, bank_transaction_id, description, created_at) FROM stdin;
1	buy	1	\N	1	1.31259857	2000.00	1523.69508937	1	1	4	Покупка 1.31259857 PLT по курсу 1523.70 ₽	2026-05-03 10:45:39.825741
2	buy	1	\N	4	216.93791919	4000.00	18.43845472	1	1	5	Покупка 216.93791919 NCH по курсу 18.44 ₽	2026-05-03 10:49:10.940978
3	sell	1	\N	4	216.93791919	4799.48	22.12374004	1	1	6	Продажа 216.93791919 NCH по курсу 22.12 ₽	2026-05-03 10:50:26.507403
4	buy	1	\N	4	765.86398579	10000.00	13.05714877	1	1	7	Покупка 765.86398579 NCH по курсу 13.06 ₽	2026-05-03 11:07:35.26237
5	sell	1	\N	4	765.86398579	28449.90	37.14745835	1	1	8	Продажа 765.86398579 NCH по курсу 37.15 ₽	2026-05-03 11:33:50.126159
\.


--
-- TOC entry 5292 (class 0 OID 49881)
-- Dependencies: 242
-- Data for Name: crypto_wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crypto_wallets (id, user_id, currency_id, balance, address, created_at) FROM stdin;
15	1	2	0.00000000	0x0e509d8eebd534ccf31af6b70f4b6b69948233bc	2026-05-03 10:45:07.586602
16	1	3	0.00000000	0x54368edfa9276baedf11d1edda5ad248d159f749	2026-05-03 10:45:07.587589
14	1	1	1.31259857	0xbd6a3f0c465f49d83752438a9fde9ad00a587965	2026-05-03 10:45:07.58141
17	1	4	0.00000000	0xb16701328e7986c73a7b835799dd14f825606313	2026-05-03 10:45:07.588536
\.


--
-- TOC entry 5290 (class 0 OID 49849)
-- Dependencies: 240
-- Data for Name: cryptocurrencies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cryptocurrencies (id, symbol, name, description, icon_color, icon_letter, base_price, current_price, volatility, jump_intensity, jump_sigma, drift, mean_reversion, last_updated, is_active) FROM stdin;
1	PLT	Plutus Coin	Флагманская монета банка PlutusBank. Низкая волатильность, надёжный актив.	#20a9bc	P	1500.00000000	1434.31170929	0.00500	0.02000	0.02000	0.00010	0.03000	2026-05-03 13:28:58.07801	t
2	STC	StarCoin	Сбалансированная монета со средней волатильностью.	#7C3AED	S	750.00000000	699.79156184	0.01200	0.05000	0.04000	-0.00010	0.02500	2026-05-03 13:28:58.07801	t
3	MGN	Magnum	Высокая капитализация и заметные колебания. Для опытных инвесторов.	#F59E0B	M	4500.00000000	5014.94584685	0.02000	0.08000	0.06000	0.00020	0.02000	2026-05-03 13:28:58.07801	t
4	NCH	Nicheons	Мем-коин с экстремальной волатильностью и непредсказуемыми скачками.	#EF4444	N	25.00000000	19.43308809	0.04000	0.15000	0.12000	0.00000	0.01500	2026-05-03 13:28:58.07801	t
\.


--
-- TOC entry 5277 (class 0 OID 49620)
-- Dependencies: 222
-- Data for Name: loan_products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_products (id, name, category, annual_rate, min_amount, max_amount, min_term_months, max_term_months, description, is_active, created_at) FROM stdin;
1	Ипотека	mortgage	8.50	500000.00	30000000.00	12	360	Кредит на покупку жилья на первичном и вторичном рынке	t	2026-05-02 15:09:01.152615
2	Автокредит	auto	12.90	100000.00	5000000.00	6	84	Финансирование покупки нового или подержанного автомобиля	t	2026-05-02 15:09:01.152615
3	На технику	electronics	15.50	10000.00	500000.00	3	36	Рассрочка на смартфоны, ноутбуки и бытовую технику	t	2026-05-02 15:09:01.152615
4	Потребительский	personal	18.90	30000.00	3000000.00	3	60	Кредит наличными на любые цели без залога	t	2026-05-02 15:09:01.152615
\.


--
-- TOC entry 5283 (class 0 OID 49704)
-- Dependencies: 230
-- Data for Name: loan_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_schedule (id, loan_id, payment_number, due_date, principal_part, interest_part, total_amount, status, paid_at, transaction_id) FROM stdin;
1	1	1	2026-06-02	9844.14	472.50	10316.64	paid	2026-05-03 11:34:05.952772	9
2	1	2	2026-07-02	9999.19	317.45	10316.64	paid	2026-05-03 11:34:09.290289	10
3	1	3	2026-08-02	10156.67	159.97	10316.64	paid	2026-05-03 11:34:10.600881	11
\.


--
-- TOC entry 5278 (class 0 OID 49640)
-- Dependencies: 223
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loans (id, user_id, product_id, target_account_id, bank_account_id, principal, annual_rate, term_months, monthly_payment, total_paid, remaining_balance, status, issued_at, next_payment_date, closed_at) FROM stdin;
1	1	4	1	3	30000.00	18.90	3	10316.64	30949.92	0.00	closed	2026-05-02 16:56:58.634283	2026-08-02	2026-05-03 11:34:10.600881
\.


--
-- TOC entry 5286 (class 0 OID 49723)
-- Dependencies: 234
-- Data for Name: transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.transactions (id, from_account_id, to_account_id, amount, transaction_type, description, status, created_at) FROM stdin;
1	\N	1	5000.00	external	Пополнение счёта	completed	2026-03-28 07:00:57.995455
2	1	2	1111.00	internal		completed	2026-03-28 07:01:59.064235
3	3	1	30000.00	loan_disbursement	Выдача кредита	completed	2026-05-02 16:56:58.634283
4	1	\N	2000.00	external	Покупка 1.31259857 PLT по курсу 1523.70 ₽	completed	2026-05-03 10:45:39.825741
5	1	\N	4000.00	external	Покупка 216.93791919 NCH по курсу 18.44 ₽	completed	2026-05-03 10:49:10.940978
6	\N	1	4799.48	external	Продажа 216.93791919 NCH по курсу 22.12 ₽	completed	2026-05-03 10:50:26.507403
7	1	\N	10000.00	external	Покупка 765.86398579 NCH по курсу 13.06 ₽	completed	2026-05-03 11:07:35.26237
8	\N	1	28449.90	external	Продажа 765.86398579 NCH по курсу 37.15 ₽	completed	2026-05-03 11:33:50.126159
9	1	3	10316.64	loan_payment	Погашение кредита	completed	2026-05-03 11:34:05.952772
10	1	3	10316.64	loan_payment	Погашение кредита	completed	2026-05-03 11:34:09.290289
11	1	3	10316.64	loan_payment	Погашение кредита	completed	2026-05-03 11:34:10.600881
\.


--
-- TOC entry 5279 (class 0 OID 49659)
-- Dependencies: 224
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, phone, password_hash, created_at, updated_at, first_name, last_name, middle_name, date_of_birth, passport_series, passport_number, address, primary_account_id, is_system_user) FROM stdin;
2	system@plutusbank.local	+70000000000	x	2026-05-02 16:48:25.629555	2026-05-02 16:48:25.629555	PlutusBank	System	\N	\N	\N	\N		\N	t
1	kondrashobdevs@gmail.com	+71112223344	32363dcb3726ef4801badd2d1d0ae00f:b288ac8fee2c57334084b9fd0b9e89663d56f4ffa8fd0486e067b7870e916e83	2026-03-28 06:59:44.524079	2026-03-28 06:59:44.524079	Даниил	Кондрашов	Владимирович	2002-01-19	5465	176583		2	f
\.


--
-- TOC entry 5314 (class 0 OID 0)
-- Dependencies: 221
-- Name: accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_id_seq', 3, true);


--
-- TOC entry 5315 (class 0 OID 0)
-- Dependencies: 227
-- Name: cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cards_id_seq', 2, true);


--
-- TOC entry 5316 (class 0 OID 0)
-- Dependencies: 246
-- Name: crypto_price_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crypto_price_history_id_seq', 964, true);


--
-- TOC entry 5317 (class 0 OID 0)
-- Dependencies: 243
-- Name: crypto_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crypto_transactions_id_seq', 5, true);


--
-- TOC entry 5318 (class 0 OID 0)
-- Dependencies: 241
-- Name: crypto_wallets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crypto_wallets_id_seq', 17, true);


--
-- TOC entry 5319 (class 0 OID 0)
-- Dependencies: 239
-- Name: cryptocurrencies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cryptocurrencies_id_seq', 4, true);


--
-- TOC entry 5320 (class 0 OID 0)
-- Dependencies: 229
-- Name: loan_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_products_id_seq', 4, true);


--
-- TOC entry 5321 (class 0 OID 0)
-- Dependencies: 231
-- Name: loan_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_schedule_id_seq', 3, true);


--
-- TOC entry 5322 (class 0 OID 0)
-- Dependencies: 233
-- Name: loans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loans_id_seq', 1, true);


--
-- TOC entry 5323 (class 0 OID 0)
-- Dependencies: 236
-- Name: transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_id_seq', 11, true);


--
-- TOC entry 5324 (class 0 OID 0)
-- Dependencies: 238
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 2, true);


--
-- TOC entry 5045 (class 2606 OID 49755)
-- Name: accounts accounts_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_account_number_key UNIQUE (account_number);


--
-- TOC entry 5047 (class 2606 OID 49757)
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 5063 (class 2606 OID 49759)
-- Name: cards cards_card_number_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_card_number_unique UNIQUE (card_number);


--
-- TOC entry 5065 (class 2606 OID 49761)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- TOC entry 5096 (class 2606 OID 50015)
-- Name: crypto_price_history crypto_price_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_price_history
    ADD CONSTRAINT crypto_price_history_pkey PRIMARY KEY (id);


--
-- TOC entry 5092 (class 2606 OID 49926)
-- Name: crypto_transactions crypto_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 5084 (class 2606 OID 49896)
-- Name: crypto_wallets crypto_wallets_address_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_address_key UNIQUE (address);


--
-- TOC entry 5086 (class 2606 OID 49894)
-- Name: crypto_wallets crypto_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_pkey PRIMARY KEY (id);


--
-- TOC entry 5080 (class 2606 OID 49877)
-- Name: cryptocurrencies cryptocurrencies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cryptocurrencies
    ADD CONSTRAINT cryptocurrencies_pkey PRIMARY KEY (id);


--
-- TOC entry 5082 (class 2606 OID 49879)
-- Name: cryptocurrencies cryptocurrencies_symbol_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cryptocurrencies
    ADD CONSTRAINT cryptocurrencies_symbol_key UNIQUE (symbol);


--
-- TOC entry 5049 (class 2606 OID 49763)
-- Name: loan_products loan_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products
    ADD CONSTRAINT loan_products_pkey PRIMARY KEY (id);


--
-- TOC entry 5073 (class 2606 OID 49765)
-- Name: loan_schedule loan_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_pkey PRIMARY KEY (id);


--
-- TOC entry 5053 (class 2606 OID 49767)
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- TOC entry 5078 (class 2606 OID 49769)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 5090 (class 2606 OID 49898)
-- Name: crypto_wallets uq_user_currency; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT uq_user_currency UNIQUE (user_id, currency_id);


--
-- TOC entry 5057 (class 2606 OID 49771)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 5059 (class 2606 OID 49773)
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- TOC entry 5061 (class 2606 OID 49775)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5066 (class 1259 OID 49776)
-- Name: idx_cards_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_account_id ON public.cards USING btree (account_id);


--
-- TOC entry 5067 (class 1259 OID 49777)
-- Name: idx_cards_card_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_card_number ON public.cards USING btree (card_number);


--
-- TOC entry 5068 (class 1259 OID 49778)
-- Name: idx_cards_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_is_active ON public.cards USING btree (is_active);


--
-- TOC entry 5097 (class 1259 OID 50021)
-- Name: idx_cph_currency_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cph_currency_time ON public.crypto_price_history USING btree (currency_id, recorded_at DESC);


--
-- TOC entry 5093 (class 1259 OID 49958)
-- Name: idx_crypto_tx_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_tx_created ON public.crypto_transactions USING btree (created_at DESC);


--
-- TOC entry 5094 (class 1259 OID 49957)
-- Name: idx_crypto_tx_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_tx_user ON public.crypto_transactions USING btree (user_id);


--
-- TOC entry 5087 (class 1259 OID 49910)
-- Name: idx_crypto_wallets_addr; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_wallets_addr ON public.crypto_wallets USING btree (address);


--
-- TOC entry 5088 (class 1259 OID 49909)
-- Name: idx_crypto_wallets_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_wallets_user ON public.crypto_wallets USING btree (user_id);


--
-- TOC entry 5050 (class 1259 OID 49779)
-- Name: idx_loans_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_status ON public.loans USING btree (status);


--
-- TOC entry 5051 (class 1259 OID 49780)
-- Name: idx_loans_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_user ON public.loans USING btree (user_id);


--
-- TOC entry 5069 (class 1259 OID 49781)
-- Name: idx_schedule_due; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_due ON public.loan_schedule USING btree (due_date);


--
-- TOC entry 5070 (class 1259 OID 49782)
-- Name: idx_schedule_loan; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_loan ON public.loan_schedule USING btree (loan_id);


--
-- TOC entry 5071 (class 1259 OID 49783)
-- Name: idx_schedule_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_status ON public.loan_schedule USING btree (status);


--
-- TOC entry 5074 (class 1259 OID 49784)
-- Name: idx_transactions_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_created ON public.transactions USING btree (created_at DESC);


--
-- TOC entry 5075 (class 1259 OID 49785)
-- Name: idx_transactions_from; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_from ON public.transactions USING btree (from_account_id);


--
-- TOC entry 5076 (class 1259 OID 49786)
-- Name: idx_transactions_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_to ON public.transactions USING btree (to_account_id);


--
-- TOC entry 5054 (class 1259 OID 49787)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- TOC entry 5055 (class 1259 OID 49788)
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- TOC entry 5272 (class 2618 OID 49789)
-- Name: active_loans_view protect_loan_delete; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE protect_loan_delete AS
    ON DELETE TO public.active_loans_view DO INSTEAD  UPDATE public.loans SET status = 'closed'::character varying, closed_at = CURRENT_TIMESTAMP
  WHERE (loans.id = old.loan_id);


--
-- TOC entry 5273 (class 2618 OID 49790)
-- Name: user_cards_view update_card_limits; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE update_card_limits AS
    ON UPDATE TO public.user_cards_view DO INSTEAD  UPDATE public.cards SET daily_limit = new.daily_limit, monthly_limit = new.monthly_limit
  WHERE (cards.id = old.card_id);


--
-- TOC entry 5118 (class 2620 OID 49791)
-- Name: cards check_card_number_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_card_number_validity BEFORE INSERT OR UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.validate_card_number_trigger();


--
-- TOC entry 5119 (class 2620 OID 49792)
-- Name: cards trigger_update_cards_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_cards_timestamp BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.update_cards_updated_at();


--
-- TOC entry 5098 (class 2606 OID 49793)
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5104 (class 2606 OID 49798)
-- Name: cards cards_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- TOC entry 5117 (class 2606 OID 50016)
-- Name: crypto_price_history crypto_price_history_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_price_history
    ADD CONSTRAINT crypto_price_history_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.cryptocurrencies(id) ON DELETE CASCADE;


--
-- TOC entry 5111 (class 2606 OID 49952)
-- Name: crypto_transactions crypto_transactions_bank_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_bank_transaction_id_fkey FOREIGN KEY (bank_transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 5112 (class 2606 OID 49942)
-- Name: crypto_transactions crypto_transactions_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_card_id_fkey FOREIGN KEY (card_id) REFERENCES public.cards(id);


--
-- TOC entry 5113 (class 2606 OID 49932)
-- Name: crypto_transactions crypto_transactions_counterparty_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_counterparty_user_id_fkey FOREIGN KEY (counterparty_user_id) REFERENCES public.users(id);


--
-- TOC entry 5114 (class 2606 OID 49937)
-- Name: crypto_transactions crypto_transactions_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.cryptocurrencies(id);


--
-- TOC entry 5115 (class 2606 OID 49947)
-- Name: crypto_transactions crypto_transactions_related_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_related_account_id_fkey FOREIGN KEY (related_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5116 (class 2606 OID 49927)
-- Name: crypto_transactions crypto_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5109 (class 2606 OID 49904)
-- Name: crypto_wallets crypto_wallets_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.cryptocurrencies(id);


--
-- TOC entry 5110 (class 2606 OID 49899)
-- Name: crypto_wallets crypto_wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5105 (class 2606 OID 49803)
-- Name: loan_schedule loan_schedule_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- TOC entry 5106 (class 2606 OID 49808)
-- Name: loan_schedule loan_schedule_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 5099 (class 2606 OID 49813)
-- Name: loans loans_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5100 (class 2606 OID 49818)
-- Name: loans loans_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.loan_products(id);


--
-- TOC entry 5101 (class 2606 OID 49823)
-- Name: loans loans_target_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_target_account_id_fkey FOREIGN KEY (target_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5102 (class 2606 OID 49828)
-- Name: loans loans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5107 (class 2606 OID 49833)
-- Name: transactions transactions_from_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_from_account_id_fkey FOREIGN KEY (from_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5108 (class 2606 OID 49838)
-- Name: transactions transactions_to_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_to_account_id_fkey FOREIGN KEY (to_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5103 (class 2606 OID 49843)
-- Name: users users_primary_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_primary_account_id_fkey FOREIGN KEY (primary_account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


-- Completed on 2026-05-03 19:33:35

--
-- PostgreSQL database dump complete
--

\unrestrict I29pbrbk59IDR0EPTcRlaYIrLqnpIAQulYzCYJqML5KepyPhYJFCYpZ2NGT8MNi


--
-- PostgreSQL database dump
--

\restrict EIpcH37whiajKi5CSqYVDzMTYQE0Z1u4TFuX6nYJwVfIRTBNifQy1zZ1okLzQZK

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-06-03 19:03:12

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
-- TOC entry 5377 (class 0 OID 0)
-- Dependencies: 5
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 308 (class 1255 OID 49959)
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
-- TOC entry 290 (class 1255 OID 49605)
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
-- TOC entry 291 (class 1255 OID 49606)
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
-- TOC entry 298 (class 1255 OID 49607)
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
-- TOC entry 305 (class 1255 OID 49608)
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
-- TOC entry 306 (class 1255 OID 49609)
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
    CONSTRAINT accounts_account_type_check CHECK (((account_type)::text = ANY (ARRAY[('debit'::character varying)::text, ('credit'::character varying)::text, ('loan'::character varying)::text, ('bank_loan_fund'::character varying)::text, ('bank_deposit_fund'::character varying)::text])))
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
-- TOC entry 5378 (class 0 OID 0)
-- Dependencies: 221
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- TOC entry 251 (class 1259 OID 50058)
-- Name: deposits; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deposits (
    id integer NOT NULL,
    user_id integer NOT NULL,
    principal numeric(15,2) NOT NULL,
    current_balance numeric(15,2) NOT NULL,
    annual_rate numeric(5,2) NOT NULL,
    term_months integer NOT NULL,
    is_replenishable boolean DEFAULT false NOT NULL,
    opened_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    matures_at date NOT NULL,
    last_interest_date date DEFAULT CURRENT_DATE NOT NULL,
    total_interest numeric(15,2) DEFAULT 0 NOT NULL,
    total_topups numeric(15,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    closed_at timestamp without time zone,
    CONSTRAINT chk_dep_balance CHECK ((current_balance >= (0)::numeric)),
    CONSTRAINT chk_dep_principal CHECK ((principal > (0)::numeric)),
    CONSTRAINT chk_dep_rate CHECK (((annual_rate > (0)::numeric) AND (annual_rate < (100)::numeric))),
    CONSTRAINT chk_dep_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'matured'::character varying, 'closed'::character varying])::text[]))),
    CONSTRAINT chk_dep_term CHECK (((term_months >= 1) AND (term_months <= 12)))
);


ALTER TABLE public.deposits OWNER TO postgres;

--
-- TOC entry 254 (class 1259 OID 50136)
-- Name: active_deposits_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.active_deposits_view AS
 SELECT id,
    user_id,
    principal,
    current_balance,
    annual_rate,
    term_months,
    is_replenishable,
    opened_at,
    matures_at,
    total_interest,
    total_topups,
    status,
    (matures_at <= CURRENT_DATE) AS can_claim,
    (matures_at - CURRENT_DATE) AS days_remaining
   FROM public.deposits d
  WHERE ((status)::text = 'active'::text);


ALTER VIEW public.active_deposits_view OWNER TO postgres;

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
-- TOC entry 5379 (class 0 OID 0)
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
-- TOC entry 5380 (class 0 OID 0)
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
-- TOC entry 5381 (class 0 OID 0)
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
-- TOC entry 5382 (class 0 OID 0)
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
-- TOC entry 5383 (class 0 OID 0)
-- Dependencies: 239
-- Name: cryptocurrencies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cryptocurrencies_id_seq OWNED BY public.cryptocurrencies.id;


--
-- TOC entry 253 (class 1259 OID 50096)
-- Name: deposit_operations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.deposit_operations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    deposit_id integer,
    savings_id integer,
    operation_type character varying(30) NOT NULL,
    amount numeric(15,2) NOT NULL,
    balance_after numeric(15,2) NOT NULL,
    transaction_id integer,
    description character varying(255) DEFAULT ''::character varying,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_op_target CHECK ((((deposit_id IS NOT NULL) AND (savings_id IS NULL)) OR ((deposit_id IS NULL) AND (savings_id IS NOT NULL)))),
    CONSTRAINT chk_op_type CHECK (((operation_type)::text = ANY ((ARRAY['savings_open'::character varying, 'savings_topup'::character varying, 'savings_withdraw'::character varying, 'savings_interest'::character varying, 'deposit_open'::character varying, 'deposit_topup'::character varying, 'deposit_payout'::character varying, 'deposit_interest'::character varying])::text[])))
);


ALTER TABLE public.deposit_operations OWNER TO postgres;

--
-- TOC entry 252 (class 1259 OID 50095)
-- Name: deposit_operations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deposit_operations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.deposit_operations_id_seq OWNER TO postgres;

--
-- TOC entry 5384 (class 0 OID 0)
-- Dependencies: 252
-- Name: deposit_operations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deposit_operations_id_seq OWNED BY public.deposit_operations.id;


--
-- TOC entry 250 (class 1259 OID 50057)
-- Name: deposits_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.deposits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.deposits_id_seq OWNER TO postgres;

--
-- TOC entry 5385 (class 0 OID 0)
-- Dependencies: 250
-- Name: deposits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.deposits_id_seq OWNED BY public.deposits.id;


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
-- TOC entry 5386 (class 0 OID 0)
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
-- TOC entry 5387 (class 0 OID 0)
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
-- TOC entry 5388 (class 0 OID 0)
-- Dependencies: 233
-- Name: loans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.loans_id_seq OWNED BY public.loans.id;


--
-- TOC entry 249 (class 1259 OID 50025)
-- Name: savings_accounts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.savings_accounts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    balance numeric(15,2) DEFAULT 0 NOT NULL,
    annual_rate numeric(5,2) DEFAULT 10.00 NOT NULL,
    last_interest_date date DEFAULT CURRENT_DATE NOT NULL,
    total_interest_paid numeric(15,2) DEFAULT 0 NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    closed_at timestamp without time zone,
    CONSTRAINT chk_savings_balance CHECK ((balance >= (0)::numeric)),
    CONSTRAINT chk_savings_rate CHECK (((annual_rate > (0)::numeric) AND (annual_rate < (100)::numeric))),
    CONSTRAINT chk_savings_status CHECK (((status)::text = ANY ((ARRAY['active'::character varying, 'closed'::character varying])::text[])))
);


ALTER TABLE public.savings_accounts OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 50024)
-- Name: savings_accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.savings_accounts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.savings_accounts_id_seq OWNER TO postgres;

--
-- TOC entry 5389 (class 0 OID 0)
-- Dependencies: 248
-- Name: savings_accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.savings_accounts_id_seq OWNED BY public.savings_accounts.id;


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
    CONSTRAINT transactions_transaction_type_check CHECK (((transaction_type)::text = ANY (ARRAY[('internal'::character varying)::text, ('external'::character varying)::text, ('loan_disbursement'::character varying)::text, ('loan_payment'::character varying)::text, ('savings_topup'::character varying)::text, ('savings_withdraw'::character varying)::text, ('savings_interest'::character varying)::text, ('deposit_open'::character varying)::text, ('deposit_topup'::character varying)::text, ('deposit_payout'::character varying)::text, ('deposit_interest'::character varying)::text])))
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
-- TOC entry 5390 (class 0 OID 0)
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
-- TOC entry 5391 (class 0 OID 0)
-- Dependencies: 238
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- TOC entry 4993 (class 2604 OID 49747)
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- TOC entry 5010 (class 2604 OID 49748)
-- Name: cards id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards ALTER COLUMN id SET DEFAULT nextval('public.cards_id_seq'::regclass);


--
-- TOC entry 5043 (class 2604 OID 50008)
-- Name: crypto_price_history id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_price_history ALTER COLUMN id SET DEFAULT nextval('public.crypto_price_history_id_seq'::regclass);


--
-- TOC entry 5040 (class 2604 OID 49915)
-- Name: crypto_transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions ALTER COLUMN id SET DEFAULT nextval('public.crypto_transactions_id_seq'::regclass);


--
-- TOC entry 5037 (class 2604 OID 49884)
-- Name: crypto_wallets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets ALTER COLUMN id SET DEFAULT nextval('public.crypto_wallets_id_seq'::regclass);


--
-- TOC entry 5026 (class 2604 OID 49852)
-- Name: cryptocurrencies id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cryptocurrencies ALTER COLUMN id SET DEFAULT nextval('public.cryptocurrencies_id_seq'::regclass);


--
-- TOC entry 5059 (class 2604 OID 50099)
-- Name: deposit_operations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposit_operations ALTER COLUMN id SET DEFAULT nextval('public.deposit_operations_id_seq'::regclass);


--
-- TOC entry 5052 (class 2604 OID 50061)
-- Name: deposits id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposits ALTER COLUMN id SET DEFAULT nextval('public.deposits_id_seq'::regclass);


--
-- TOC entry 4997 (class 2604 OID 49749)
-- Name: loan_products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products ALTER COLUMN id SET DEFAULT nextval('public.loan_products_id_seq'::regclass);


--
-- TOC entry 5020 (class 2604 OID 49750)
-- Name: loan_schedule id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule ALTER COLUMN id SET DEFAULT nextval('public.loan_schedule_id_seq'::regclass);


--
-- TOC entry 5001 (class 2604 OID 49751)
-- Name: loans id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans ALTER COLUMN id SET DEFAULT nextval('public.loans_id_seq'::regclass);


--
-- TOC entry 5045 (class 2604 OID 50028)
-- Name: savings_accounts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.savings_accounts ALTER COLUMN id SET DEFAULT nextval('public.savings_accounts_id_seq'::regclass);


--
-- TOC entry 5022 (class 2604 OID 49752)
-- Name: transactions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions ALTER COLUMN id SET DEFAULT nextval('public.transactions_id_seq'::regclass);


--
-- TOC entry 5005 (class 2604 OID 49753)
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- TOC entry 5344 (class 0 OID 49610)
-- Dependencies: 220
-- Data for Name: accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accounts (id, user_id, account_number, balance, account_type, created_at) FROM stdin;
16	9	40817810576958349026	115871.54	debit	2026-05-23 11:22:21.024715
8	3	40817810817018369805	500.00	debit	2026-05-23 11:05:43.562494
9	4	40817810059723192222	250.00	debit	2026-05-23 11:05:43.564764
20	11	40817810022400631946	500.00	debit	2026-05-23 11:25:51.036095
21	12	40817810283924350097	250.00	debit	2026-05-23 11:25:51.037672
7	3	40817810424694493393	91850.00	debit	2026-05-23 11:05:43.546564
11	5	40817810963127855978	500.00	debit	2026-05-23 11:05:49.16545
12	6	40817810989050943199	250.00	debit	2026-05-23 11:05:49.16729
10	5	40817810185631146544	91850.00	debit	2026-05-23 11:05:49.163596
4	2	40817810000000000002	100059000.00	bank_deposit_fund	2026-05-05 20:10:26.047024
19	11	40817810221342510321	115871.54	debit	2026-05-23 11:25:51.033864
14	7	40817810742140399350	500.00	debit	2026-05-23 11:19:39.85097
3	2	40817810000000000001	99456045.90	bank_loan_fund	2026-05-02 16:48:25.629555
15	8	40817810187706287975	250.00	debit	2026-05-23 11:19:39.852583
6	1	40817810769819173356	483717.26	debit	2026-05-15 19:43:13.942141
22	1	40817810600104563178	5000.00	debit	2026-05-24 08:57:49.215116
13	7	40817810341292812532	115871.54	debit	2026-05-23 11:19:39.84933
2	1	40817810741953746212	2376.88	debit	2026-03-28 07:01:46.625811
5	1	40817810934580929836	29631.70	debit	2026-05-15 19:40:16.76183
1	1	40817810241179458708	3135.31	debit	2026-03-28 07:00:43.046755
17	9	40817810194931370056	500.00	debit	2026-05-23 11:22:21.0273
18	10	40817810325349661764	250.00	debit	2026-05-23 11:22:21.02934
\.


--
-- TOC entry 5349 (class 0 OID 49677)
-- Dependencies: 226
-- Data for Name: cards; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cards (id, account_id, card_number, card_holder_name, expiry_date, cvv_hash, card_type, card_brand, is_active, is_blocked, daily_limit, monthly_limit, pin_hash, failed_attempts, last_used_at, created_at, updated_at) FROM stdin;
1	1	4409 6564 3169 8321	КОНДРАШОВ ДАНИИЛ	2031-03-28	83eaf4dc5e19bcbeb23801e2c3e08c4a89cc82d0a42a903767f9c938d1deac4f	debit	visa	t	f	100000.00	500000.00	13b4088f2f9a285e22128d11a6a1a31254baf9936c0192655d32a7f563aad503	0	\N	2026-03-28 07:00:43.06697	2026-03-28 07:00:43.06697
2	2	5592 7686 2417 8369	КОНДРАШОВ ДАНИИЛ	2031-03-28	a77b6cbdf6fae1676369dea1e1ea675e4c2400c9e43bd535fdfd9395cb48cbaa	debit	mastercard	t	f	100000.00	500000.00	44e081556e1ae4a2bfed531a64dd185109c416e4248cec40ce28a7c272edafa9	0	\N	2026-03-28 07:01:46.629608	2026-03-28 07:01:46.629608
3	5	4612 5826 2184 3456	КОНДРАШОВ ДАНИИЛ	2031-05-15	9556b82499cc0aaf86aee7f0d253e17c61b7ef73d48a295f37d98f08b04ffa7f	debit	visa	t	f	100000.00	500000.00	d9eb1c864cfaa8b6deef076edd37d9fe3403212dfae3d243947419118e4a06f2	0	\N	2026-05-15 19:40:16.811482	2026-05-15 19:40:16.811482
4	6	2039 4041 4113 9035	КОНДРАШОВ ДАНИИЛ	2031-05-15	d4ee9f58e5860574ca98e3b4839391e7a356328d4bd6afecefc2381df5f5b41b	debit	mir	t	f	100000.00	500000.00	2e27bb07e506e9824ae32f9b0e2b52278c203f35cdfd04bad872f45fa4831a1d	0	\N	2026-05-15 19:43:13.953377	2026-05-15 19:43:13.953377
5	7	4777 2315 0469 0557	IVAN TESTOVYI	2030-05-23	test_cvc_hash_aaa	debit	visa	f	t	100000.00	500000.00	test_pin_hash_bbb	0	\N	2026-05-23 11:05:43.605815	2026-05-23 11:05:43.76738
6	10	4252 6702 3886 6971	IVAN TESTOVYI	2030-05-23	test_cvc_hash_aaa	debit	visa	f	t	100000.00	500000.00	test_pin_hash_bbb	0	\N	2026-05-23 11:05:49.173864	2026-05-23 11:05:49.285939
7	13	4845 5454 6226 5930	IVAN TESTOVYI	2030-05-23	test_cvc_hash_aaa	debit	visa	f	t	100000.00	500000.00	test_pin_hash_bbb	0	\N	2026-05-23 11:19:39.858997	2026-05-23 11:19:40.001252
8	16	4815 1647 8931 8905	IVAN TESTOVYI	2030-05-23	test_cvc_hash_aaa	debit	visa	f	t	100000.00	500000.00	test_pin_hash_bbb	0	\N	2026-05-23 11:22:21.036454	2026-05-23 11:22:21.186441
9	19	4191 1797 6906 1964	IVAN TESTOVYI	2030-05-23	test_cvc_hash_aaa	debit	visa	f	t	100000.00	500000.00	test_pin_hash_bbb	0	\N	2026-05-23 11:25:51.049431	2026-05-23 11:25:51.21758
10	22	2015 6669 0576 0614	КОНДРАШОВ ДАНИИЛ	2031-05-24	1d2028ddcd746a7ee87dd0739d7435602b77d4908f96e27ebdad57b09aa27b69	debit	mir	t	f	100000.00	500000.00	b79f0b7e843f7ee2cf2e3e2d198075fecc37be79a6257ed732bc7f4e0f009e26	0	\N	2026-05-24 08:57:49.273081	2026-05-24 08:57:49.273081
\.


--
-- TOC entry 5365 (class 0 OID 50005)
-- Dependencies: 247
-- Data for Name: crypto_price_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crypto_price_history (id, currency_id, price, recorded_at) FROM stdin;
4941	1	1543.19126229	2026-05-30 09:01:22.87741
4942	2	706.93712771	2026-05-30 09:01:22.87741
4943	3	4205.16049428	2026-05-30 09:01:22.87741
4944	4	25.58045414	2026-05-30 09:01:22.87741
4945	1	1497.01673934	2026-05-30 09:01:52.882418
4946	2	703.72793219	2026-05-30 09:01:52.882418
4947	3	4030.17647758	2026-05-30 09:01:52.882418
4948	4	27.90700911	2026-05-30 09:01:52.882418
4949	1	1510.39093000	2026-05-30 09:02:22.882372
4950	2	687.84356187	2026-05-30 09:02:22.882372
4951	3	3980.35969402	2026-05-30 09:02:22.882372
4952	4	25.67288895	2026-05-30 09:02:22.882372
4953	1	1507.78854415	2026-05-30 09:02:52.882767
4954	2	672.38071447	2026-05-30 09:02:52.882767
4955	3	4635.07292505	2026-05-30 09:02:52.882767
4956	4	24.83003744	2026-05-30 09:02:52.882767
4957	1	1515.36757071	2026-05-30 09:03:22.880656
4958	2	735.22806615	2026-05-30 09:03:22.880656
4959	3	4828.55222175	2026-05-30 09:03:22.880656
4960	4	32.34399762	2026-05-30 09:03:22.880656
4961	1	1479.12070204	2026-05-30 09:03:52.878419
4962	2	696.14743659	2026-05-30 09:03:52.878419
4963	3	4605.30369888	2026-05-30 09:03:52.878419
4964	4	32.93528575	2026-05-30 09:03:52.878419
4965	1	1499.02465047	2026-05-30 09:04:22.880083
4966	2	724.50370671	2026-05-30 09:04:22.880083
4967	3	4816.80821288	2026-05-30 09:04:22.880083
4968	4	27.24360462	2026-05-30 09:04:22.880083
4969	1	1484.72418683	2026-05-30 09:04:52.888105
4970	2	749.17115401	2026-05-30 09:04:52.888105
4971	3	4652.34773600	2026-05-30 09:04:52.888105
4972	4	28.81394644	2026-05-30 09:04:52.888105
4973	1	1475.85520627	2026-05-30 09:05:22.886716
4974	2	782.06116083	2026-05-30 09:05:22.886716
4975	3	4494.33880967	2026-05-30 09:05:22.886716
4976	4	22.45016970	2026-05-30 09:05:22.886716
4977	1	1496.73746648	2026-05-30 09:05:52.886129
4978	2	745.97025947	2026-05-30 09:05:52.886129
4979	3	4033.60500305	2026-05-30 09:05:52.886129
4980	4	20.68337293	2026-05-30 09:05:52.886129
4981	1	1520.81536655	2026-05-30 09:06:22.880433
4982	2	737.86752957	2026-05-30 09:06:22.880433
4983	3	4026.35176902	2026-05-30 09:06:22.880433
4984	4	17.05840650	2026-05-30 09:06:22.880433
4985	1	1521.96565557	2026-05-30 09:06:52.88652
4986	2	775.03599139	2026-05-30 09:06:52.88652
4987	3	4514.93087329	2026-05-30 09:06:52.88652
4988	4	19.73334235	2026-05-30 09:06:52.88652
4989	1	1476.56571313	2026-05-30 09:07:22.883518
4990	2	695.43977355	2026-05-30 09:07:22.883518
4991	3	4311.72732439	2026-05-30 09:07:22.883518
4992	4	20.26463908	2026-05-30 09:07:22.883518
4993	1	1480.16422391	2026-05-30 09:07:52.886126
4994	2	753.14840383	2026-05-30 09:07:52.886126
4995	3	4109.74279709	2026-05-30 09:07:52.886126
4996	4	26.93421082	2026-05-30 09:07:52.886126
4997	1	1495.74485411	2026-05-30 09:08:22.883265
4998	2	741.61789908	2026-05-30 09:08:22.883265
4999	3	4277.28786673	2026-05-30 09:08:22.883265
5000	4	29.20129023	2026-05-30 09:08:22.883265
5001	1	1466.62294446	2026-05-30 09:08:52.879589
5002	2	770.37024067	2026-05-30 09:08:52.879589
5003	3	4265.06947949	2026-05-30 09:08:52.879589
5004	4	29.22182772	2026-05-30 09:08:52.879589
5005	1	1543.66985604	2026-05-30 09:09:22.88165
5006	2	742.28756684	2026-05-30 09:09:22.88165
5007	3	4848.29427600	2026-05-30 09:09:22.88165
5008	4	31.54173142	2026-05-30 09:09:22.88165
5009	1	1578.02943532	2026-05-30 09:09:52.880863
5010	2	744.13947925	2026-05-30 09:09:52.880863
5011	3	4663.21987272	2026-05-30 09:09:52.880863
5012	4	29.39973561	2026-05-30 09:09:52.880863
5013	1	1573.78664427	2026-05-30 09:10:22.880676
5014	2	704.51129572	2026-05-30 09:10:22.880676
5015	3	4475.17822579	2026-05-30 09:10:22.880676
5016	4	34.23013172	2026-05-30 09:10:22.880676
5017	1	1534.33035094	2026-05-30 09:10:52.878553
5018	2	741.53810315	2026-05-30 09:10:52.878553
5019	3	4217.06270804	2026-05-30 09:10:52.878553
5020	4	32.97710854	2026-05-30 09:10:52.878553
5021	1	1462.02613938	2026-05-30 09:11:22.89066
5022	2	762.95936986	2026-05-30 09:11:22.89066
5023	3	4234.57622121	2026-05-30 09:11:22.89066
5024	4	22.97544260	2026-05-30 09:11:22.89066
5025	1	1456.94825504	2026-05-30 09:11:52.886414
5026	2	765.11914083	2026-05-30 09:11:52.886414
5027	3	4643.54752711	2026-05-30 09:11:52.886414
5028	4	24.95543871	2026-05-30 09:11:52.886414
5029	1	1443.46801199	2026-05-30 09:12:22.883739
5030	2	703.75643222	2026-05-30 09:12:22.883739
5031	3	5090.03853200	2026-05-30 09:12:22.883739
5032	4	25.78043368	2026-05-30 09:12:22.883739
5033	1	1425.10687594	2026-05-30 09:12:52.885446
5034	2	776.20681968	2026-05-30 09:12:52.885446
5035	3	5089.60733551	2026-05-30 09:12:52.885446
5036	4	26.87241651	2026-05-30 09:12:52.885446
5037	1	1448.51111820	2026-05-30 09:13:22.88525
5038	2	764.94946847	2026-05-30 09:13:22.88525
5039	3	4861.16242434	2026-05-30 09:13:22.88525
5040	4	26.87491627	2026-05-30 09:13:22.88525
5041	1	1465.99817484	2026-05-30 09:13:52.879523
5042	2	787.40436036	2026-05-30 09:13:52.879523
5043	3	4462.84545702	2026-05-30 09:13:52.879523
5044	4	28.98541594	2026-05-30 09:13:52.879523
5045	1	1467.24454925	2026-05-30 09:14:22.899333
5046	2	796.19061216	2026-05-30 09:14:22.899333
5047	3	4402.97945039	2026-05-30 09:14:22.899333
5048	4	33.59391117	2026-05-30 09:14:22.899333
5049	1	1488.53667234	2026-05-30 09:14:52.899493
5050	2	729.36914915	2026-05-30 09:14:52.899493
5051	3	4177.98539781	2026-05-30 09:14:52.899493
5052	4	27.20398315	2026-05-30 09:14:52.899493
5053	1	1532.32749526	2026-05-30 09:15:22.897212
5054	2	738.36368599	2026-05-30 09:15:22.897212
5055	3	4457.80266146	2026-05-30 09:15:22.897212
5056	4	23.35992379	2026-05-30 09:15:22.897212
5057	1	1545.22099150	2026-05-30 09:15:52.905157
5058	2	752.70188968	2026-05-30 09:15:52.905157
5059	3	4218.55281054	2026-05-30 09:15:52.905157
5060	4	17.45029777	2026-05-30 09:15:52.905157
5061	1	1488.14848217	2026-05-30 09:16:22.896229
5062	2	736.23252266	2026-05-30 09:16:22.896229
5063	3	3981.20194030	2026-05-30 09:16:22.896229
5064	4	13.68370341	2026-05-30 09:16:22.896229
5065	1	1479.51145836	2026-05-30 09:16:52.900421
5066	2	702.66395059	2026-05-30 09:16:52.900421
5067	3	3918.44105899	2026-05-30 09:16:52.900421
5068	4	16.24586936	2026-05-30 09:16:52.900421
5069	1	1527.01206966	2026-05-30 09:17:22.898824
5070	2	666.98144129	2026-05-30 09:17:22.898824
5071	3	4175.63338671	2026-05-30 09:17:22.898824
5072	4	17.00733404	2026-05-30 09:17:22.898824
5073	1	1538.97682151	2026-05-30 09:17:52.897671
5074	2	674.37321590	2026-05-30 09:17:52.897671
5075	3	4275.02944192	2026-05-30 09:17:52.897671
5076	4	18.89648665	2026-05-30 09:17:52.897671
5077	1	1507.71011145	2026-05-30 09:18:22.899654
5078	2	672.85632911	2026-05-30 09:18:22.899654
5079	3	4683.76934460	2026-05-30 09:18:22.899654
5080	4	20.11920773	2026-05-30 09:18:22.899654
5081	1	1529.37943505	2026-05-30 09:18:52.898234
5082	2	725.58605220	2026-05-30 09:18:52.898234
5083	3	4426.92751534	2026-05-30 09:18:52.898234
5084	4	28.93826457	2026-05-30 09:18:52.898234
5085	1	1529.95493782	2026-05-30 09:19:22.897303
5086	2	709.98448348	2026-05-30 09:19:22.897303
5087	3	4280.83958914	2026-05-30 09:19:22.897303
5088	4	40.70137037	2026-05-30 09:19:22.897303
5089	1	1476.53165218	2026-05-30 09:19:52.895162
5090	2	741.35125291	2026-05-30 09:19:52.895162
5091	3	4021.73967262	2026-05-30 09:19:52.895162
5092	4	34.71502389	2026-05-30 09:19:52.895162
\.


--
-- TOC entry 5363 (class 0 OID 49912)
-- Dependencies: 244
-- Data for Name: crypto_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crypto_transactions (id, operation_type, user_id, counterparty_user_id, currency_id, coin_amount, rub_amount, price_per_coin, card_id, related_account_id, bank_transaction_id, description, created_at) FROM stdin;
1	buy	1	\N	1	1.31259857	2000.00	1523.69508937	1	1	4	Покупка 1.31259857 PLT по курсу 1523.70 ₽	2026-05-03 10:45:39.825741
2	buy	1	\N	4	216.93791919	4000.00	18.43845472	1	1	5	Покупка 216.93791919 NCH по курсу 18.44 ₽	2026-05-03 10:49:10.940978
3	sell	1	\N	4	216.93791919	4799.48	22.12374004	1	1	6	Продажа 216.93791919 NCH по курсу 22.12 ₽	2026-05-03 10:50:26.507403
4	buy	1	\N	4	765.86398579	10000.00	13.05714877	1	1	7	Покупка 765.86398579 NCH по курсу 13.06 ₽	2026-05-03 11:07:35.26237
5	sell	1	\N	4	765.86398579	28449.90	37.14745835	1	1	8	Продажа 765.86398579 NCH по курсу 37.15 ₽	2026-05-03 11:33:50.126159
6	buy	1	\N	3	1.28004184	5000.00	3906.12232864	1	1	12	Покупка MGN за 5000.00 ₽	2026-05-04 19:02:00.202435
7	sell	1	\N	3	1.28004184	6517.67	5091.76321858	1	1	13	Продажа MGN за 6517.67 ₽	2026-05-04 19:20:49.886137
8	buy	1	\N	2	2.89992328	2000.00	689.67341877	1	1	14	Покупка STC за 2000.00 ₽	2026-05-04 19:25:21.014599
9	buy	1	\N	4	145.82275197	3000.00	20.57292130	1	1	17	Покупка NCH за 3000.00 ₽	2026-05-05 18:30:25.844815
10	sell	1	\N	4	145.82275197	2025.44	13.88972531	3	5	19	Продажа NCH за 2025.44 ₽	2026-05-15 19:41:03.087807
11	buy	1	\N	4	822.83595800	20000.00	24.30618133	3	5	45	Покупка NCH за 20000.00 ₽	2026-05-15 19:57:31.777655
12	sell	1	\N	2	2.89992328	2429.18	837.66884633	1	1	46	Продажа STC за 2429.18 ₽	2026-05-15 19:57:55.692918
13	buy	7	\N	1	0.65651629	1000.00	1523.19144901	7	13	73	Покупка PLT за 1000.00 ₽	2026-05-23 11:19:39.979304
14	sell	7	\N	1	0.16412907	250.00	1523.19144901	7	13	74	Продажа PLT за 250.00 ₽	2026-05-23 11:19:39.984221
15	transfer_out	7	8	1	0.06565163	\N	\N	\N	\N	\N	Перевод 0.06565163 PLT → Получатель П.	2026-05-23 11:19:39.988138
16	transfer_in	8	7	1	0.06565163	\N	\N	\N	\N	\N	Получено 0.06565163 PLT	2026-05-23 11:19:39.988138
17	buy	9	\N	1	0.65874416	1000.00	1518.04002558	8	16	85	Покупка PLT за 1000.00 ₽	2026-05-23 11:22:21.162929
18	sell	9	\N	1	0.16468604	250.00	1518.04002558	8	16	86	Продажа PLT за 250.00 ₽	2026-05-23 11:22:21.167904
19	transfer_out	9	10	1	0.06587442	\N	\N	\N	\N	\N	Перевод 0.06587442 PLT → Получатель П.	2026-05-23 11:22:21.172217
20	transfer_in	10	9	1	0.06587442	\N	\N	\N	\N	\N	Получено 0.06587442 PLT	2026-05-23 11:22:21.172217
21	buy	11	\N	1	0.63911421	1000.00	1564.66556664	9	19	97	Покупка PLT за 1000.00 ₽	2026-05-23 11:25:51.194984
22	sell	11	\N	1	0.15977855	250.00	1564.66556664	9	19	98	Продажа PLT за 250.00 ₽	2026-05-23 11:25:51.199798
23	transfer_out	11	12	1	0.06391142	\N	\N	\N	\N	\N	Перевод 0.06391142 PLT → Получатель П.	2026-05-23 11:25:51.204373
24	transfer_in	12	11	1	0.06391142	\N	\N	\N	\N	\N	Получено 0.06391142 PLT	2026-05-23 11:25:51.204373
\.


--
-- TOC entry 5361 (class 0 OID 49881)
-- Dependencies: 242
-- Data for Name: crypto_wallets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.crypto_wallets (id, user_id, currency_id, balance, address, created_at) FROM stdin;
14	1	1	1.31259857	0xbd6a3f0c465f49d83752438a9fde9ad00a587965	2026-05-03 10:45:07.58141
16	1	3	0.00000000	0x54368edfa9276baedf11d1edda5ad248d159f749	2026-05-03 10:45:07.587589
17	1	4	822.83595800	0xb16701328e7986c73a7b835799dd14f825606313	2026-05-03 10:45:07.588536
15	1	2	0.00000000	0x0e509d8eebd534ccf31af6b70f4b6b69948233bc	2026-05-03 10:45:07.586602
18	3	1	0.00000000	0x3d1f11327902f8ce850633132fb49a124dd58ffd	2026-05-23 11:05:43.718952
19	3	2	0.00000000	0x8b4aeec8002c24f4c3611c1d08eacbbb9b837353	2026-05-23 11:05:43.742082
20	3	3	0.00000000	0x50b89e2c4ea79d4b55fbc09f4e37382a9b71efc6	2026-05-23 11:05:43.743604
21	3	4	0.00000000	0xd2642fd57f8c3dde8656a00991d42bbc11bcc056	2026-05-23 11:05:43.745173
22	4	1	0.00000000	0xd543affabdd32e8fb7930dca062fe29aaf56dc45	2026-05-23 11:05:43.750641
23	4	2	0.00000000	0x7a06f1f7af47a219970af3efd138316a9c9f64b1	2026-05-23 11:05:43.751982
24	4	3	0.00000000	0xe6fcec76bd726b8fe2977283fbacf9990b29b9bb	2026-05-23 11:05:43.753444
25	4	4	0.00000000	0x42ae8f429a593b6399ff77672f1a5a7cb46301a0	2026-05-23 11:05:43.754829
26	5	1	0.00000000	0x1b842194187ad69b9da1d269adda884a4deae290	2026-05-23 11:05:49.264085
27	5	2	0.00000000	0x385d6d7e8e39797d51cb5e482b9acb616241b533	2026-05-23 11:05:49.265435
28	5	3	0.00000000	0xe7bcb1fe6c6b6772e11edabb9629d5abe2c795fe	2026-05-23 11:05:49.266676
29	5	4	0.00000000	0x9d616fea7503431a8c5305c9d4f227d790c62592	2026-05-23 11:05:49.267835
30	6	1	0.00000000	0x0ccbd1f84189a3cf638f3165fc29f559ddd47028	2026-05-23 11:05:49.272129
31	6	2	0.00000000	0x96e3dcdca78887e0a7eebb05b6c853860fa44bb2	2026-05-23 11:05:49.273557
32	6	3	0.00000000	0x71d9156ba6aa14eaff54c9606b86ba8f770e6bee	2026-05-23 11:05:49.274846
33	6	4	0.00000000	0xd63fa053eeb914bbe59450843842434f1caf9a0e	2026-05-23 11:05:49.275956
35	7	2	0.00000000	0x98f01a5d5daa1f1cc6b264cf29828f3fcbd2f4fd	2026-05-23 11:19:39.957689
36	7	3	0.00000000	0x49ba9b880eca8fae225726ca82ccd6a3885215f8	2026-05-23 11:19:39.959034
37	7	4	0.00000000	0xcfe8485ae3d7a765b6aaf79c64c7286b9197039f	2026-05-23 11:19:39.960261
39	8	2	0.00000000	0x75bd63d84086f1a7671c744de28cffd9095c7c66	2026-05-23 11:19:39.973003
40	8	3	0.00000000	0xba493e4e521fc5083fb1673c348d3773caea4147	2026-05-23 11:19:39.974301
41	8	4	0.00000000	0x19299eb46faa13a8ff513136c7e4486c8e3ee987	2026-05-23 11:19:39.975422
34	7	1	0.42673559	0xa31170bc320f98661cbbec7b0bd09429fb83daf0	2026-05-23 11:19:39.956304
38	8	1	0.06565163	0xfc1caf82f99c5b0ee7655633895d4dfdb85d08bc	2026-05-23 11:19:39.96459
43	9	2	0.00000000	0x0e2797f24e6efa742ca9f477eb7e48ec52245d8a	2026-05-23 11:22:21.142361
44	9	3	0.00000000	0xcd0d099aea48f93909d2d052fecda5b10e5c989a	2026-05-23 11:22:21.143929
45	9	4	0.00000000	0xd88d22bd06618fcd2dd6972a40d2edb9e65870c2	2026-05-23 11:22:21.14518
47	10	2	0.00000000	0xc3cf0e2ff4dba01ab3930c5185970920f2b2481c	2026-05-23 11:22:21.156858
48	10	3	0.00000000	0x3cf457b77b02697c0de5bdc4e13d8604385959cc	2026-05-23 11:22:21.158104
49	10	4	0.00000000	0x88e425f030381ce4c171feda2ae762542fe45835	2026-05-23 11:22:21.15928
42	9	1	0.42818370	0x7deef9097361cd99787fc1d0979819787fc75d8f	2026-05-23 11:22:21.14096
46	10	1	0.06587442	0xdf2fc960f7bc93a6d6b54d60060eb64e2e34fe5d	2026-05-23 11:22:21.149609
51	11	2	0.00000000	0x1a2fa34574cd97f649ff5f9babba1e110708d57f	2026-05-23 11:25:51.170292
52	11	3	0.00000000	0xc67dd4c3d3f503ae635480afa43de03c3901acb6	2026-05-23 11:25:51.171781
53	11	4	0.00000000	0x350ef23f9421d9d76f3d8bd1463623899f4ebd6e	2026-05-23 11:25:51.173271
55	12	2	0.00000000	0xc81528e6e36e66d4504f00be9e56911e7ca2dd26	2026-05-23 11:25:51.188305
56	12	3	0.00000000	0x1a872d3d40b6c5b360b52273b49b86047b910552	2026-05-23 11:25:51.189752
57	12	4	0.00000000	0x24517c99f3eda9a2c82099dd8a10085df715d67c	2026-05-23 11:25:51.190996
50	11	1	0.41542424	0x206b4908abed7b8b00ba28233bc6cffc58ec23d9	2026-05-23 11:25:51.167961
54	12	1	0.06391142	0x6f932b0c07f78653a6beead0b636e9adbea4d5bb	2026-05-23 11:25:51.178121
58	14	1	0.00000000	0x6e5d779a7ca73469d5f3976fb48f809e66729696	2026-05-24 09:28:58.562975
59	14	2	0.00000000	0x7f78c593467bd0db96789b496b04afbb143f9247	2026-05-24 09:28:58.592032
60	14	3	0.00000000	0xdd228d633b0bcff3518d96a59b18b4db750a5a66	2026-05-24 09:28:58.593831
61	14	4	0.00000000	0x9b083ada8beace133893980849128796eb668b4d	2026-05-24 09:28:58.595634
\.


--
-- TOC entry 5359 (class 0 OID 49849)
-- Dependencies: 240
-- Data for Name: cryptocurrencies; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cryptocurrencies (id, symbol, name, description, icon_color, icon_letter, base_price, current_price, volatility, jump_intensity, jump_sigma, drift, mean_reversion, last_updated, is_active) FROM stdin;
1	PLT	Plutus Coin	Флагманская монета банка PlutusBank. Низкая волатильность, надёжный актив.	#20a9bc	P	1500.00000000	1478.28635193	0.00500	0.02000	0.02000	0.00010	0.03000	2026-05-30 09:19:55.893799	t
2	STC	StarCoin	Сбалансированная монета со средней волатильностью.	#7C3AED	S	750.00000000	740.97765754	0.01200	0.05000	0.04000	-0.00010	0.02500	2026-05-30 09:19:55.893799	t
3	MGN	Magnum	Высокая капитализация и заметные колебания. Для опытных инвесторов.	#F59E0B	M	4500.00000000	3931.03655067	0.02000	0.08000	0.06000	0.00020	0.02000	2026-05-30 09:19:55.893799	t
4	NCH	Nicheons	Мем-коин с экстремальной волатильностью и непредсказуемыми скачками.	#EF4444	N	25.00000000	33.65141661	0.04000	0.15000	0.12000	0.00000	0.01500	2026-05-30 09:19:55.893799	t
\.


--
-- TOC entry 5371 (class 0 OID 50096)
-- Dependencies: 253
-- Data for Name: deposit_operations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deposit_operations (id, user_id, deposit_id, savings_id, operation_type, amount, balance_after, transaction_id, description, created_at) FROM stdin;
1	1	\N	1	savings_open	10000.00	10000.00	15	Открытие накопительного счёта	2026-05-05 17:32:09.729656
2	1	1	\N	deposit_open	5000.00	5000.00	16	Открытие вклада	2026-05-05 17:45:09.374439
3	1	\N	1	savings_interest	27.43	10027.43	\N	Начислено за 10 дн.	2026-05-15 19:43:49.393867
4	1	1	\N	deposit_interest	20.59	5020.59	\N	Начислено за 10 дн.	2026-05-15 19:43:49.411284
5	1	2	\N	deposit_open	2000.00	2000.00	30	Открытие вклада	2026-05-15 19:44:10.917057
6	1	3	\N	deposit_open	5000.00	5000.00	38	Открытие вклада	2026-05-15 19:55:56.356582
7	3	\N	2	savings_open	2000.00	2000.00	50	Открытие накопительного счёта	2026-05-23 11:05:43.676505
8	3	\N	2	savings_topup	500.00	2500.00	51	Пополнение	2026-05-23 11:05:43.684304
9	3	\N	2	savings_withdraw	300.00	2200.00	52	Снятие на карту	2026-05-23 11:05:43.689691
10	3	4	\N	deposit_open	5000.00	5000.00	53	Открытие вклада	2026-05-23 11:05:43.697128
11	3	4	\N	deposit_topup	200.00	5200.00	54	Пополнение	2026-05-23 11:05:43.705128
12	5	\N	3	savings_open	2000.00	2000.00	58	Открытие накопительного счёта	2026-05-23 11:05:49.22936
13	5	\N	3	savings_topup	500.00	2500.00	59	Пополнение	2026-05-23 11:05:49.234647
14	5	\N	3	savings_withdraw	300.00	2200.00	60	Снятие на карту	2026-05-23 11:05:49.239551
15	5	5	\N	deposit_open	5000.00	5000.00	61	Открытие вклада	2026-05-23 11:05:49.245459
16	5	5	\N	deposit_topup	200.00	5200.00	62	Пополнение	2026-05-23 11:05:49.252579
17	7	\N	4	savings_open	2000.00	2000.00	68	Открытие накопительного счёта	2026-05-23 11:19:39.921832
18	7	\N	4	savings_topup	500.00	2500.00	69	Пополнение	2026-05-23 11:19:39.926837
19	7	\N	4	savings_withdraw	300.00	2200.00	70	Снятие на карту	2026-05-23 11:19:39.931632
20	7	6	\N	deposit_open	5000.00	5000.00	71	Открытие вклада	2026-05-23 11:19:39.93731
21	7	6	\N	deposit_topup	200.00	5200.00	72	Пополнение	2026-05-23 11:19:39.944909
22	9	\N	5	savings_open	2000.00	2000.00	80	Открытие накопительного счёта	2026-05-23 11:22:21.105653
23	9	\N	5	savings_topup	500.00	2500.00	81	Пополнение	2026-05-23 11:22:21.110815
24	9	\N	5	savings_withdraw	300.00	2200.00	82	Снятие на карту	2026-05-23 11:22:21.115627
25	9	7	\N	deposit_open	5000.00	5000.00	83	Открытие вклада	2026-05-23 11:22:21.121772
26	9	7	\N	deposit_topup	200.00	5200.00	84	Пополнение	2026-05-23 11:22:21.129268
27	11	\N	6	savings_open	2000.00	2000.00	92	Открытие накопительного счёта	2026-05-23 11:25:51.127013
28	11	\N	6	savings_topup	500.00	2500.00	93	Пополнение	2026-05-23 11:25:51.133208
29	11	\N	6	savings_withdraw	300.00	2200.00	94	Снятие на карту	2026-05-23 11:25:51.138462
30	11	8	\N	deposit_open	5000.00	5000.00	95	Открытие вклада	2026-05-23 11:25:51.145773
31	11	8	\N	deposit_topup	200.00	5200.00	96	Пополнение	2026-05-23 11:25:51.153137
32	1	\N	1	savings_interest	24.75	10052.18	\N	Начислено за 9 дн.	2026-05-24 08:49:36.116843
33	1	1	\N	deposit_interest	18.60	5039.19	\N	Начислено за 9 дн.	2026-05-24 08:49:36.135408
34	1	2	\N	deposit_interest	4.44	2004.44	\N	Начислено за 9 дн.	2026-05-24 08:49:36.137851
35	1	3	\N	deposit_interest	16.05	5016.05	\N	Начислено за 9 дн.	2026-05-24 08:49:36.139566
36	1	\N	1	savings_interest	16.54	10068.72	\N	Начислено за 6 дн.	2026-05-30 09:01:44.698544
37	1	1	\N	deposit_interest	12.44	5051.63	\N	Начислено за 6 дн.	2026-05-30 09:01:44.712469
38	1	2	\N	deposit_interest	2.97	2007.41	\N	Начислено за 6 дн.	2026-05-30 09:01:44.714566
39	1	3	\N	deposit_interest	10.73	5026.78	\N	Начислено за 6 дн.	2026-05-30 09:01:44.716652
\.


--
-- TOC entry 5369 (class 0 OID 50058)
-- Dependencies: 251
-- Data for Name: deposits; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.deposits (id, user_id, principal, current_balance, annual_rate, term_months, is_replenishable, opened_at, matures_at, last_interest_date, total_interest, total_topups, status, closed_at) FROM stdin;
4	3	5000.00	5200.00	9.00	3	t	2026-05-23 11:05:43.697128	2026-08-23	2026-05-23	0.00	200.00	active	\N
5	5	5000.00	5200.00	9.00	3	t	2026-05-23 11:05:49.245459	2026-08-23	2026-05-23	0.00	200.00	active	\N
6	7	5000.00	5200.00	9.00	3	t	2026-05-23 11:19:39.93731	2026-08-23	2026-05-23	0.00	200.00	active	\N
7	9	5000.00	5200.00	9.00	3	t	2026-05-23 11:22:21.121772	2026-08-23	2026-05-23	0.00	200.00	active	\N
8	11	5000.00	5200.00	9.00	3	t	2026-05-23 11:25:51.145773	2026-08-23	2026-05-23	0.00	200.00	active	\N
1	1	5000.00	5051.63	15.00	12	f	2026-05-05 17:45:09.374439	2027-05-05	2026-05-30	51.63	0.00	active	\N
2	1	2000.00	2007.41	9.00	3	f	2026-05-15 19:44:10.917057	2026-08-15	2026-05-30	7.41	0.00	active	\N
3	1	5000.00	5026.78	13.00	6	f	2026-05-15 19:55:56.356582	2026-11-15	2026-05-30	26.78	0.00	active	\N
\.


--
-- TOC entry 5346 (class 0 OID 49620)
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
-- TOC entry 5352 (class 0 OID 49704)
-- Dependencies: 230
-- Data for Name: loan_schedule; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loan_schedule (id, loan_id, payment_number, due_date, principal_part, interest_part, total_amount, status, paid_at, transaction_id) FROM stdin;
1	1	1	2026-06-02	9844.14	472.50	10316.64	paid	2026-05-03 11:34:05.952772	9
2	1	2	2026-07-02	9999.19	317.45	10316.64	paid	2026-05-03 11:34:09.290289	10
3	1	3	2026-08-02	10156.67	159.97	10316.64	paid	2026-05-03 11:34:10.600881	11
12	2	9	2027-02-15	15363.65	241.98	15605.63	pending	\N	\N
4	2	1	2026-06-15	13558.14	2047.50	15605.64	paid	2026-05-15 19:41:38.207689	21
5	2	2	2026-07-15	13771.68	1833.96	15605.64	paid	2026-05-15 19:41:39.496965	22
6	2	3	2026-08-15	13988.58	1617.06	15605.64	paid	2026-05-15 19:41:39.87771	23
7	2	4	2026-09-15	14208.90	1396.74	15605.64	paid	2026-05-15 19:41:40.193695	24
8	2	5	2026-10-15	14432.69	1172.95	15605.64	paid	2026-05-15 19:41:40.486692	25
9	2	6	2026-11-15	14660.01	945.63	15605.64	paid	2026-05-15 19:41:40.714881	26
10	2	7	2026-12-15	14890.91	714.73	15605.64	paid	2026-05-15 19:41:40.960862	27
11	2	8	2027-01-15	15125.44	480.20	15605.64	paid	2026-05-15 19:41:41.232734	28
13	3	1	2026-06-15	75471.75	3622.50	79094.25	paid	2026-05-15 19:44:41.519257	32
14	3	2	2026-07-15	76660.43	2433.82	79094.25	paid	2026-05-15 19:44:42.157826	33
15	3	3	2026-08-15	77867.82	1226.42	79094.24	paid	2026-05-15 19:45:32.968593	37
16	4	1	2026-06-15	75471.75	3622.50	79094.25	paid	2026-05-15 19:56:46.304597	41
17	4	2	2026-07-15	76660.43	2433.82	79094.25	paid	2026-05-15 19:56:46.809794	42
18	4	3	2026-08-15	77867.82	1226.42	79094.24	paid	2026-05-15 19:56:47.311706	43
20	5	2	2026-07-23	4903.49	324.97	5228.46	pending	\N	\N
21	5	3	2026-08-23	4966.83	261.63	5228.46	pending	\N	\N
22	5	4	2026-09-23	5030.98	197.48	5228.46	pending	\N	\N
23	5	5	2026-10-23	5095.96	132.50	5228.46	pending	\N	\N
24	5	6	2026-11-23	5161.78	66.67	5228.45	pending	\N	\N
19	5	1	2026-06-23	4840.96	387.50	5228.46	paid	2026-05-23 11:19:39.91533	67
26	6	2	2026-07-23	4903.49	324.97	5228.46	pending	\N	\N
27	6	3	2026-08-23	4966.83	261.63	5228.46	pending	\N	\N
28	6	4	2026-09-23	5030.98	197.48	5228.46	pending	\N	\N
29	6	5	2026-10-23	5095.96	132.50	5228.46	pending	\N	\N
30	6	6	2026-11-23	5161.78	66.67	5228.45	pending	\N	\N
25	6	1	2026-06-23	4840.96	387.50	5228.46	paid	2026-05-23 11:22:21.098814	79
32	7	2	2026-07-23	4903.49	324.97	5228.46	pending	\N	\N
33	7	3	2026-08-23	4966.83	261.63	5228.46	pending	\N	\N
34	7	4	2026-09-23	5030.98	197.48	5228.46	pending	\N	\N
35	7	5	2026-10-23	5095.96	132.50	5228.46	pending	\N	\N
36	7	6	2026-11-23	5161.78	66.67	5228.45	pending	\N	\N
31	7	1	2026-06-23	4840.96	387.50	5228.46	paid	2026-05-23 11:25:51.118489	91
37	8	1	2026-06-24	40307.35	7560.00	47867.35	pending	\N	\N
38	8	2	2026-07-24	40942.19	6925.16	47867.35	pending	\N	\N
39	8	3	2026-08-24	41587.03	6280.32	47867.35	pending	\N	\N
40	8	4	2026-09-24	42242.03	5625.32	47867.35	pending	\N	\N
41	8	5	2026-10-24	42907.34	4960.01	47867.35	pending	\N	\N
42	8	6	2026-11-24	43583.13	4284.22	47867.35	pending	\N	\N
43	8	7	2026-12-24	44269.56	3597.79	47867.35	pending	\N	\N
44	8	8	2027-01-24	44966.81	2900.54	47867.35	pending	\N	\N
45	8	9	2027-02-24	45675.04	2192.31	47867.35	pending	\N	\N
46	8	10	2027-03-24	46394.42	1472.93	47867.35	pending	\N	\N
47	8	11	2027-04-24	47125.10	742.22	47867.32	pending	\N	\N
\.


--
-- TOC entry 5347 (class 0 OID 49640)
-- Dependencies: 223
-- Data for Name: loans; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.loans (id, user_id, product_id, target_account_id, bank_account_id, principal, annual_rate, term_months, monthly_payment, total_paid, remaining_balance, status, issued_at, next_payment_date, closed_at) FROM stdin;
1	1	4	1	3	30000.00	18.90	3	10316.64	30949.92	0.00	closed	2026-05-02 16:56:58.634283	2026-08-02	2026-05-03 11:34:10.600881
2	1	4	2	3	130000.00	18.90	9	15605.64	124845.12	15605.62	active	2026-05-15 19:41:28.81112	2027-02-15	\N
3	1	4	6	3	230000.00	18.90	3	79094.25	237282.74	0.00	closed	2026-05-15 19:44:34.04058	2026-08-15	2026-05-15 19:45:32.968593
4	1	4	5	3	230000.00	18.90	3	79094.25	237282.74	0.00	closed	2026-05-15 19:56:23.605084	2026-08-15	2026-05-15 19:56:47.311706
5	7	3	13	3	30000.00	15.50	6	5228.46	5228.46	26142.29	active	2026-05-23 11:19:39.902897	2026-07-23	\N
6	9	3	16	3	30000.00	15.50	6	5228.46	5228.46	26142.29	active	2026-05-23 11:22:21.087236	2026-07-23	\N
7	11	3	19	3	30000.00	15.50	6	5228.46	5228.46	26142.29	active	2026-05-23 11:25:51.103702	2026-07-23	\N
8	1	4	6	3	480000.00	18.90	11	47867.35	0.00	526540.83	active	2026-05-24 08:47:52.592653	2026-06-24	\N
\.


--
-- TOC entry 5367 (class 0 OID 50025)
-- Dependencies: 249
-- Data for Name: savings_accounts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.savings_accounts (id, user_id, balance, annual_rate, last_interest_date, total_interest_paid, status, created_at, closed_at) FROM stdin;
2	3	2200.00	10.00	2026-05-23	0.00	active	2026-05-23 11:05:43.676505	\N
3	5	2200.00	10.00	2026-05-23	0.00	active	2026-05-23 11:05:49.22936	\N
4	7	2200.00	10.00	2026-05-23	0.00	active	2026-05-23 11:19:39.921832	\N
5	9	2200.00	10.00	2026-05-23	0.00	active	2026-05-23 11:22:21.105653	\N
6	11	2200.00	10.00	2026-05-23	0.00	active	2026-05-23 11:25:51.127013	\N
1	1	10068.72	10.00	2026-05-30	68.72	active	2026-05-05 17:32:09.729656	\N
\.


--
-- TOC entry 5355 (class 0 OID 49723)
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
12	1	\N	5000.00	external	Покупка 1.28004184 MGN	completed	2026-05-04 19:02:00.202435
13	\N	1	6517.67	external	Продажа 1.28004184 MGN	completed	2026-05-04 19:20:49.886137
14	1	\N	2000.00	external	Покупка 2.89992328 STC	completed	2026-05-04 19:25:21.014599
15	1	4	10000.00	savings_topup	Открытие накоп. счёта	completed	2026-05-05 17:32:09.729656
16	1	4	5000.00	deposit_open	Открытие вклада	completed	2026-05-05 17:45:09.374439
17	1	\N	3000.00	external	Покупка 145.82275197 NCH	completed	2026-05-05 18:30:25.844815
18	\N	5	1000.00	external	Пополнение счёта	completed	2026-05-15 19:40:39.845742
19	\N	5	2025.44	external	Продажа 145.82275197 NCH	completed	2026-05-15 19:41:03.087807
20	3	2	130000.00	loan_disbursement	Выдача кредита	completed	2026-05-15 19:41:28.81112
21	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:38.207689
22	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:39.496965
23	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:39.87771
24	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:40.193695
25	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:40.486692
26	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:40.714881
27	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:40.960862
28	2	3	15605.64	loan_payment	Погашение кредита	completed	2026-05-15 19:41:41.232734
29	\N	1	1000.00	external	Пополнение счёта	completed	2026-05-15 19:43:32.940303
30	1	4	2000.00	deposit_open	Открытие вклада	completed	2026-05-15 19:44:10.917057
31	3	6	230000.00	loan_disbursement	Выдача кредита	completed	2026-05-15 19:44:34.04058
32	6	3	79094.25	loan_payment	Погашение кредита	completed	2026-05-15 19:44:41.519257
33	6	3	79094.25	loan_payment	Погашение кредита	completed	2026-05-15 19:44:42.157826
34	\N	6	1000.00	external	Пополнение счёта	completed	2026-05-15 19:45:09.100256
35	\N	6	5000.00	external	Пополнение счёта	completed	2026-05-15 19:45:18.230196
36	\N	6	5000.00	external	Пополнение счёта	completed	2026-05-15 19:45:21.285242
37	6	3	79094.24	loan_payment	Погашение кредита	completed	2026-05-15 19:45:32.968593
38	2	4	5000.00	deposit_open	Открытие вклада	completed	2026-05-15 19:55:56.356582
39	3	5	230000.00	loan_disbursement	Выдача кредита	completed	2026-05-15 19:56:23.605084
40	\N	5	55000.00	external	Пополнение счёта	completed	2026-05-15 19:56:38.265197
41	5	3	79094.25	loan_payment	Погашение кредита	completed	2026-05-15 19:56:46.304597
42	5	3	79094.25	loan_payment	Погашение кредита	completed	2026-05-15 19:56:46.809794
43	5	3	79094.24	loan_payment	Погашение кредита	completed	2026-05-15 19:56:47.311706
44	5	2	1111.00	internal		completed	2026-05-15 19:57:12.716169
45	5	\N	20000.00	external	Покупка 822.83595800 NCH	completed	2026-05-15 19:57:31.777655
46	\N	1	2429.18	external	Продажа 2.89992328 STC	completed	2026-05-15 19:57:55.692918
47	\N	7	100000.00	external	Пополнение счёта	completed	2026-05-23 11:05:43.623604
48	7	8	500.00	internal		completed	2026-05-23 11:05:43.647446
49	7	9	250.00	external		completed	2026-05-23 11:05:43.652498
50	7	4	2000.00	savings_topup	Открытие накоп. счёта	completed	2026-05-23 11:05:43.676505
51	7	4	500.00	savings_topup	Пополнение накоп. счёта	completed	2026-05-23 11:05:43.684304
52	4	7	300.00	savings_withdraw	Снятие с накоп. счёта	completed	2026-05-23 11:05:43.689691
53	7	4	5000.00	deposit_open	Открытие вклада	completed	2026-05-23 11:05:43.697128
54	7	4	200.00	deposit_topup	Пополнение вклада	completed	2026-05-23 11:05:43.705128
55	\N	10	100000.00	external	Пополнение счёта	completed	2026-05-23 11:05:49.186788
56	10	11	500.00	internal		completed	2026-05-23 11:05:49.207214
57	10	12	250.00	external		completed	2026-05-23 11:05:49.212331
58	10	4	2000.00	savings_topup	Открытие накоп. счёта	completed	2026-05-23 11:05:49.22936
59	10	4	500.00	savings_topup	Пополнение накоп. счёта	completed	2026-05-23 11:05:49.234647
60	4	10	300.00	savings_withdraw	Снятие с накоп. счёта	completed	2026-05-23 11:05:49.239551
61	10	4	5000.00	deposit_open	Открытие вклада	completed	2026-05-23 11:05:49.245459
62	10	4	200.00	deposit_topup	Пополнение вклада	completed	2026-05-23 11:05:49.252579
63	\N	13	100000.00	external	Пополнение счёта	completed	2026-05-23 11:19:39.871439
64	13	14	500.00	internal		completed	2026-05-23 11:19:39.890838
65	13	15	250.00	external		completed	2026-05-23 11:19:39.894964
66	3	13	30000.00	loan_disbursement	Выдача кредита	completed	2026-05-23 11:19:39.902897
67	13	3	5228.46	loan_payment	Погашение кредита	completed	2026-05-23 11:19:39.91533
68	13	4	2000.00	savings_topup	Открытие накоп. счёта	completed	2026-05-23 11:19:39.921832
69	13	4	500.00	savings_topup	Пополнение накоп. счёта	completed	2026-05-23 11:19:39.926837
70	4	13	300.00	savings_withdraw	Снятие с накоп. счёта	completed	2026-05-23 11:19:39.931632
71	13	4	5000.00	deposit_open	Открытие вклада	completed	2026-05-23 11:19:39.93731
72	13	4	200.00	deposit_topup	Пополнение вклада	completed	2026-05-23 11:19:39.944909
73	13	\N	1000.00	external	Покупка 0.65651629 PLT	completed	2026-05-23 11:19:39.979304
74	\N	13	250.00	external	Продажа 0.16412907 PLT	completed	2026-05-23 11:19:39.984221
75	\N	16	100000.00	external	Пополнение счёта	completed	2026-05-23 11:22:21.051739
76	16	17	500.00	internal		completed	2026-05-23 11:22:21.073403
77	16	18	250.00	external		completed	2026-05-23 11:22:21.078013
78	3	16	30000.00	loan_disbursement	Выдача кредита	completed	2026-05-23 11:22:21.087236
79	16	3	5228.46	loan_payment	Погашение кредита	completed	2026-05-23 11:22:21.098814
80	16	4	2000.00	savings_topup	Открытие накоп. счёта	completed	2026-05-23 11:22:21.105653
81	16	4	500.00	savings_topup	Пополнение накоп. счёта	completed	2026-05-23 11:22:21.110815
82	4	16	300.00	savings_withdraw	Снятие с накоп. счёта	completed	2026-05-23 11:22:21.115627
83	16	4	5000.00	deposit_open	Открытие вклада	completed	2026-05-23 11:22:21.121772
84	16	4	200.00	deposit_topup	Пополнение вклада	completed	2026-05-23 11:22:21.129268
85	16	\N	1000.00	external	Покупка 0.65874416 PLT	completed	2026-05-23 11:22:21.162929
86	\N	16	250.00	external	Продажа 0.16468604 PLT	completed	2026-05-23 11:22:21.167904
87	\N	19	100000.00	external	Пополнение счёта	completed	2026-05-23 11:25:51.063763
88	19	20	500.00	internal		completed	2026-05-23 11:25:51.090285
89	19	21	250.00	external		completed	2026-05-23 11:25:51.09467
90	3	19	30000.00	loan_disbursement	Выдача кредита	completed	2026-05-23 11:25:51.103702
91	19	3	5228.46	loan_payment	Погашение кредита	completed	2026-05-23 11:25:51.118489
92	19	4	2000.00	savings_topup	Открытие накоп. счёта	completed	2026-05-23 11:25:51.127013
93	19	4	500.00	savings_topup	Пополнение накоп. счёта	completed	2026-05-23 11:25:51.133208
94	4	19	300.00	savings_withdraw	Снятие с накоп. счёта	completed	2026-05-23 11:25:51.138462
95	19	4	5000.00	deposit_open	Открытие вклада	completed	2026-05-23 11:25:51.145773
96	19	4	200.00	deposit_topup	Пополнение вклада	completed	2026-05-23 11:25:51.153137
97	19	\N	1000.00	external	Покупка 0.63911421 PLT	completed	2026-05-23 11:25:51.194984
98	\N	19	250.00	external	Продажа 0.15977855 PLT	completed	2026-05-23 11:25:51.199798
99	3	6	480000.00	loan_disbursement	Выдача кредита	completed	2026-05-24 08:47:52.592653
100	\N	22	5000.00	external	Пополнение счёта	completed	2026-05-24 08:59:00.59288
\.


--
-- TOC entry 5348 (class 0 OID 49659)
-- Dependencies: 224
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, phone, password_hash, created_at, updated_at, first_name, last_name, middle_name, date_of_birth, passport_series, passport_number, address, primary_account_id, is_system_user) FROM stdin;
2	system@plutusbank.local	+70000000000	x	2026-05-02 16:48:25.629555	2026-05-02 16:48:25.629555	PlutusBank	System	\N	\N	\N	\N		\N	t
1	kondrashobdevs@gmail.com	+71112223344	32363dcb3726ef4801badd2d1d0ae00f:b288ac8fee2c57334084b9fd0b9e89663d56f4ffa8fd0486e067b7870e916e83	2026-03-28 06:59:44.524079	2026-03-28 06:59:44.524079	Даниил	Кондрашов	Владимирович	2002-01-19	5465	176583		2	f
4	userb.4343490@example.test	+79914343490	de34fac32f0632a1172bfaa86f597c02:104491f60d6a9694ed8af051e08d11bda9676f501104fa16c3ddbe6aa9581574	2026-05-23 11:05:43.53401	2026-05-23 11:05:43.53401	Пётр	Получатель	Адресатович	1992-06-21	3490	343491		\N	f
3	usera.4343490@example.test	+79904343490	d8180d0b8a32ea847cc4b8d36dd47ec6:7b02be636d4ed3fd1eb165beae249fb41ae5dd371d98de2fc1b8ca514b6f3e66	2026-05-23 11:05:43.525732	2026-05-23 11:05:43.525732	Иван	Тестовый	Сценариевич	1990-01-15	1290	343490		8	f
6	userb.4349127@example.test	+79914349127	581e1ff86827978631aa3ebd7c0785d9:40cd6ea11a143cfdcfeed82febf72fa60ab16902b58134b6a0f6058432984d68	2026-05-23 11:05:49.154219	2026-05-23 11:05:49.154219	Пётр	Получатель	Адресатович	1992-06-21	3427	349128		\N	f
5	usera.4349127@example.test	+79904349127	ef02a82c88720ebe54edcb9cd2f187a2:4af33de467d1f54655eeca34f1826a4af35868d04dcb130cf04660ee09d3b440	2026-05-23 11:05:49.151825	2026-05-23 11:05:49.151825	Иван	Тестовый	Сценариевич	1990-01-15	1227	349127		11	f
8	userb.5179815@example.test	+79915179815	be055f89a013afbe61ce0fc44286a9b7:0f7d3fc5cfeda9705856accbd88223c5c217298baa0823a6854db9b403123cef	2026-05-23 11:19:39.840162	2026-05-23 11:19:39.840162	Пётр	Получатель	Адресатович	1992-06-21	3415	179816		\N	f
7	usera.5179815@example.test	+79905179815	a0f496f1f18ec55948d1ea396053b635:49c048049ef4ef4e8e02ba33ebd5250cd618e1ef62275976dbe432aa12640898	2026-05-23 11:19:39.837879	2026-05-23 11:19:39.837879	Иван	Тестовый	Сценариевич	1990-01-15	1215	179815		14	f
10	userb.5340991@example.test	+79915340991	60d1270afd7f5ca6f2700f2032defc59:c0cc3dbb67155e1ea14d9440e99c11309b11c623494a2375aa89e9a35fbbb978	2026-05-23 11:22:21.015155	2026-05-23 11:22:21.015155	Пётр	Получатель	Адресатович	1992-06-21	3491	340992		\N	f
9	usera.5340991@example.test	+79905340991	b96772b5c3dba8c601a0917cedd65c71:cc3ddc7ec00e0d928158baf9152315d062350f16951603cbe19cbc495fb563fd	2026-05-23 11:22:21.012674	2026-05-23 11:22:21.012674	Иван	Тестовый	Сценариевич	1990-01-15	1291	340991		17	f
12	userb.5550992@example.test	+79915550992	7977f86e77c8c0ae694d2e0046305113:895b3ec5bddcfc7ca78c52b566b30703ab0498fca539d4f46cb0b4b056d32003	2026-05-23 11:25:51.023013	2026-05-23 11:25:51.023013	Пётр	Получатель	Адресатович	1992-06-21	3492	550993		\N	f
11	usera.5550992@example.test	+79905550992	75ccc00afb42365f7d6ca4c475003c95:896c8d3e046ceda0ae247f97feda025dcc96d1ec0d7c21f0f33193ff251a642c	2026-05-23 11:25:51.019895	2026-05-23 11:25:51.019895	Иван	Тестовый	Сценариевич	1990-01-15	1292	550992		20	f
13	dfsfsd@gmail.com	+71231231231	fcf58f2856d268ad46b40121453cbddf:10af7c804eb95e040474e3c3fec560079e926c043c0f0447b99b94837b0d595b	2026-05-24 09:22:00.850226	2026-05-24 09:22:00.850226	вфывфыв	вфывфы	вфывфыв	2002-01-19	1111	111111		\N	f
14	fdsf@gmail.com	+71234567898	cfec1ccfc617b07f95239700bae4f2c5:8bc3960ddcbb4612a7e2c55df462886e05aa7ac7736fe596fc07f523bb202394	2026-05-24 09:28:58.238776	2026-05-24 09:28:58.238776	jhgjghjghj	jhjghjghj	jghjghjgh	2002-11-11	1231	321312		\N	f
\.


--
-- TOC entry 5392 (class 0 OID 0)
-- Dependencies: 221
-- Name: accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accounts_id_seq', 22, true);


--
-- TOC entry 5393 (class 0 OID 0)
-- Dependencies: 227
-- Name: cards_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cards_id_seq', 10, true);


--
-- TOC entry 5394 (class 0 OID 0)
-- Dependencies: 246
-- Name: crypto_price_history_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crypto_price_history_id_seq', 5092, true);


--
-- TOC entry 5395 (class 0 OID 0)
-- Dependencies: 243
-- Name: crypto_transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crypto_transactions_id_seq', 24, true);


--
-- TOC entry 5396 (class 0 OID 0)
-- Dependencies: 241
-- Name: crypto_wallets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.crypto_wallets_id_seq', 61, true);


--
-- TOC entry 5397 (class 0 OID 0)
-- Dependencies: 239
-- Name: cryptocurrencies_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cryptocurrencies_id_seq', 4, true);


--
-- TOC entry 5398 (class 0 OID 0)
-- Dependencies: 252
-- Name: deposit_operations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deposit_operations_id_seq', 39, true);


--
-- TOC entry 5399 (class 0 OID 0)
-- Dependencies: 250
-- Name: deposits_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.deposits_id_seq', 8, true);


--
-- TOC entry 5400 (class 0 OID 0)
-- Dependencies: 229
-- Name: loan_products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_products_id_seq', 4, true);


--
-- TOC entry 5401 (class 0 OID 0)
-- Dependencies: 231
-- Name: loan_schedule_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loan_schedule_id_seq', 47, true);


--
-- TOC entry 5402 (class 0 OID 0)
-- Dependencies: 233
-- Name: loans_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.loans_id_seq', 8, true);


--
-- TOC entry 5403 (class 0 OID 0)
-- Dependencies: 248
-- Name: savings_accounts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.savings_accounts_id_seq', 6, true);


--
-- TOC entry 5404 (class 0 OID 0)
-- Dependencies: 236
-- Name: transactions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.transactions_id_seq', 100, true);


--
-- TOC entry 5405 (class 0 OID 0)
-- Dependencies: 238
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 14, true);


--
-- TOC entry 5091 (class 2606 OID 49755)
-- Name: accounts accounts_account_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_account_number_key UNIQUE (account_number);


--
-- TOC entry 5093 (class 2606 OID 49757)
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 5109 (class 2606 OID 49759)
-- Name: cards cards_card_number_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_card_number_unique UNIQUE (card_number);


--
-- TOC entry 5111 (class 2606 OID 49761)
-- Name: cards cards_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_pkey PRIMARY KEY (id);


--
-- TOC entry 5142 (class 2606 OID 50015)
-- Name: crypto_price_history crypto_price_history_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_price_history
    ADD CONSTRAINT crypto_price_history_pkey PRIMARY KEY (id);


--
-- TOC entry 5138 (class 2606 OID 49926)
-- Name: crypto_transactions crypto_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 5130 (class 2606 OID 49896)
-- Name: crypto_wallets crypto_wallets_address_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_address_key UNIQUE (address);


--
-- TOC entry 5132 (class 2606 OID 49894)
-- Name: crypto_wallets crypto_wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_pkey PRIMARY KEY (id);


--
-- TOC entry 5126 (class 2606 OID 49877)
-- Name: cryptocurrencies cryptocurrencies_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cryptocurrencies
    ADD CONSTRAINT cryptocurrencies_pkey PRIMARY KEY (id);


--
-- TOC entry 5128 (class 2606 OID 49879)
-- Name: cryptocurrencies cryptocurrencies_symbol_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cryptocurrencies
    ADD CONSTRAINT cryptocurrencies_symbol_key UNIQUE (symbol);


--
-- TOC entry 5155 (class 2606 OID 50111)
-- Name: deposit_operations deposit_operations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposit_operations
    ADD CONSTRAINT deposit_operations_pkey PRIMARY KEY (id);


--
-- TOC entry 5151 (class 2606 OID 50087)
-- Name: deposits deposits_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposits
    ADD CONSTRAINT deposits_pkey PRIMARY KEY (id);


--
-- TOC entry 5095 (class 2606 OID 49763)
-- Name: loan_products loan_products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_products
    ADD CONSTRAINT loan_products_pkey PRIMARY KEY (id);


--
-- TOC entry 5119 (class 2606 OID 49765)
-- Name: loan_schedule loan_schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_pkey PRIMARY KEY (id);


--
-- TOC entry 5099 (class 2606 OID 49767)
-- Name: loans loans_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_pkey PRIMARY KEY (id);


--
-- TOC entry 5147 (class 2606 OID 50047)
-- Name: savings_accounts savings_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.savings_accounts
    ADD CONSTRAINT savings_accounts_pkey PRIMARY KEY (id);


--
-- TOC entry 5124 (class 2606 OID 49769)
-- Name: transactions transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_pkey PRIMARY KEY (id);


--
-- TOC entry 5149 (class 2606 OID 50049)
-- Name: savings_accounts uq_savings_user_active; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.savings_accounts
    ADD CONSTRAINT uq_savings_user_active UNIQUE (user_id);


--
-- TOC entry 5136 (class 2606 OID 49898)
-- Name: crypto_wallets uq_user_currency; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT uq_user_currency UNIQUE (user_id, currency_id);


--
-- TOC entry 5103 (class 2606 OID 49771)
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- TOC entry 5105 (class 2606 OID 49773)
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- TOC entry 5107 (class 2606 OID 49775)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- TOC entry 5112 (class 1259 OID 49776)
-- Name: idx_cards_account_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_account_id ON public.cards USING btree (account_id);


--
-- TOC entry 5113 (class 1259 OID 49777)
-- Name: idx_cards_card_number; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_card_number ON public.cards USING btree (card_number);


--
-- TOC entry 5114 (class 1259 OID 49778)
-- Name: idx_cards_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cards_is_active ON public.cards USING btree (is_active);


--
-- TOC entry 5143 (class 1259 OID 50021)
-- Name: idx_cph_currency_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cph_currency_time ON public.crypto_price_history USING btree (currency_id, recorded_at DESC);


--
-- TOC entry 5139 (class 1259 OID 49958)
-- Name: idx_crypto_tx_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_tx_created ON public.crypto_transactions USING btree (created_at DESC);


--
-- TOC entry 5140 (class 1259 OID 49957)
-- Name: idx_crypto_tx_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_tx_user ON public.crypto_transactions USING btree (user_id);


--
-- TOC entry 5133 (class 1259 OID 49910)
-- Name: idx_crypto_wallets_addr; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_wallets_addr ON public.crypto_wallets USING btree (address);


--
-- TOC entry 5134 (class 1259 OID 49909)
-- Name: idx_crypto_wallets_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_crypto_wallets_user ON public.crypto_wallets USING btree (user_id);


--
-- TOC entry 5156 (class 1259 OID 50135)
-- Name: idx_dep_ops_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dep_ops_created_at ON public.deposit_operations USING btree (created_at DESC);


--
-- TOC entry 5157 (class 1259 OID 50133)
-- Name: idx_dep_ops_deposit; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dep_ops_deposit ON public.deposit_operations USING btree (deposit_id);


--
-- TOC entry 5158 (class 1259 OID 50134)
-- Name: idx_dep_ops_savings; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dep_ops_savings ON public.deposit_operations USING btree (savings_id);


--
-- TOC entry 5159 (class 1259 OID 50132)
-- Name: idx_dep_ops_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dep_ops_user ON public.deposit_operations USING btree (user_id);


--
-- TOC entry 5152 (class 1259 OID 50094)
-- Name: idx_deposits_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_deposits_status ON public.deposits USING btree (status);


--
-- TOC entry 5153 (class 1259 OID 50093)
-- Name: idx_deposits_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_deposits_user ON public.deposits USING btree (user_id);


--
-- TOC entry 5096 (class 1259 OID 49779)
-- Name: idx_loans_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_status ON public.loans USING btree (status);


--
-- TOC entry 5097 (class 1259 OID 49780)
-- Name: idx_loans_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_loans_user ON public.loans USING btree (user_id);


--
-- TOC entry 5144 (class 1259 OID 50056)
-- Name: idx_savings_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_savings_status ON public.savings_accounts USING btree (status);


--
-- TOC entry 5145 (class 1259 OID 50055)
-- Name: idx_savings_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_savings_user ON public.savings_accounts USING btree (user_id);


--
-- TOC entry 5115 (class 1259 OID 49781)
-- Name: idx_schedule_due; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_due ON public.loan_schedule USING btree (due_date);


--
-- TOC entry 5116 (class 1259 OID 49782)
-- Name: idx_schedule_loan; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_loan ON public.loan_schedule USING btree (loan_id);


--
-- TOC entry 5117 (class 1259 OID 49783)
-- Name: idx_schedule_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_schedule_status ON public.loan_schedule USING btree (status);


--
-- TOC entry 5120 (class 1259 OID 49784)
-- Name: idx_transactions_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_created ON public.transactions USING btree (created_at DESC);


--
-- TOC entry 5121 (class 1259 OID 49785)
-- Name: idx_transactions_from; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_from ON public.transactions USING btree (from_account_id);


--
-- TOC entry 5122 (class 1259 OID 49786)
-- Name: idx_transactions_to; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_to ON public.transactions USING btree (to_account_id);


--
-- TOC entry 5100 (class 1259 OID 49787)
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- TOC entry 5101 (class 1259 OID 49788)
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- TOC entry 5340 (class 2618 OID 49789)
-- Name: active_loans_view protect_loan_delete; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE protect_loan_delete AS
    ON DELETE TO public.active_loans_view DO INSTEAD  UPDATE public.loans SET status = 'closed'::character varying, closed_at = CURRENT_TIMESTAMP
  WHERE (loans.id = old.loan_id);


--
-- TOC entry 5341 (class 2618 OID 49790)
-- Name: user_cards_view update_card_limits; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE update_card_limits AS
    ON UPDATE TO public.user_cards_view DO INSTEAD  UPDATE public.cards SET daily_limit = new.daily_limit, monthly_limit = new.monthly_limit
  WHERE (cards.id = old.card_id);


--
-- TOC entry 5186 (class 2620 OID 49791)
-- Name: cards check_card_number_validity; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_card_number_validity BEFORE INSERT OR UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.validate_card_number_trigger();


--
-- TOC entry 5187 (class 2620 OID 49792)
-- Name: cards trigger_update_cards_timestamp; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_cards_timestamp BEFORE UPDATE ON public.cards FOR EACH ROW EXECUTE FUNCTION public.update_cards_updated_at();


--
-- TOC entry 5160 (class 2606 OID 49793)
-- Name: accounts accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5166 (class 2606 OID 49798)
-- Name: cards cards_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cards
    ADD CONSTRAINT cards_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE CASCADE;


--
-- TOC entry 5179 (class 2606 OID 50016)
-- Name: crypto_price_history crypto_price_history_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_price_history
    ADD CONSTRAINT crypto_price_history_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.cryptocurrencies(id) ON DELETE CASCADE;


--
-- TOC entry 5173 (class 2606 OID 49952)
-- Name: crypto_transactions crypto_transactions_bank_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_bank_transaction_id_fkey FOREIGN KEY (bank_transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 5174 (class 2606 OID 49942)
-- Name: crypto_transactions crypto_transactions_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_card_id_fkey FOREIGN KEY (card_id) REFERENCES public.cards(id);


--
-- TOC entry 5175 (class 2606 OID 49932)
-- Name: crypto_transactions crypto_transactions_counterparty_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_counterparty_user_id_fkey FOREIGN KEY (counterparty_user_id) REFERENCES public.users(id);


--
-- TOC entry 5176 (class 2606 OID 49937)
-- Name: crypto_transactions crypto_transactions_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.cryptocurrencies(id);


--
-- TOC entry 5177 (class 2606 OID 49947)
-- Name: crypto_transactions crypto_transactions_related_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_related_account_id_fkey FOREIGN KEY (related_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5178 (class 2606 OID 49927)
-- Name: crypto_transactions crypto_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_transactions
    ADD CONSTRAINT crypto_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5171 (class 2606 OID 49904)
-- Name: crypto_wallets crypto_wallets_currency_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_currency_id_fkey FOREIGN KEY (currency_id) REFERENCES public.cryptocurrencies(id);


--
-- TOC entry 5172 (class 2606 OID 49899)
-- Name: crypto_wallets crypto_wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.crypto_wallets
    ADD CONSTRAINT crypto_wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5182 (class 2606 OID 50117)
-- Name: deposit_operations deposit_operations_deposit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposit_operations
    ADD CONSTRAINT deposit_operations_deposit_id_fkey FOREIGN KEY (deposit_id) REFERENCES public.deposits(id) ON DELETE CASCADE;


--
-- TOC entry 5183 (class 2606 OID 50122)
-- Name: deposit_operations deposit_operations_savings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposit_operations
    ADD CONSTRAINT deposit_operations_savings_id_fkey FOREIGN KEY (savings_id) REFERENCES public.savings_accounts(id) ON DELETE CASCADE;


--
-- TOC entry 5184 (class 2606 OID 50127)
-- Name: deposit_operations deposit_operations_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposit_operations
    ADD CONSTRAINT deposit_operations_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 5185 (class 2606 OID 50112)
-- Name: deposit_operations deposit_operations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposit_operations
    ADD CONSTRAINT deposit_operations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5181 (class 2606 OID 50088)
-- Name: deposits deposits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.deposits
    ADD CONSTRAINT deposits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5167 (class 2606 OID 49803)
-- Name: loan_schedule loan_schedule_loan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_loan_id_fkey FOREIGN KEY (loan_id) REFERENCES public.loans(id) ON DELETE CASCADE;


--
-- TOC entry 5168 (class 2606 OID 49808)
-- Name: loan_schedule loan_schedule_transaction_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loan_schedule
    ADD CONSTRAINT loan_schedule_transaction_id_fkey FOREIGN KEY (transaction_id) REFERENCES public.transactions(id);


--
-- TOC entry 5161 (class 2606 OID 49813)
-- Name: loans loans_bank_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_bank_account_id_fkey FOREIGN KEY (bank_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5162 (class 2606 OID 49818)
-- Name: loans loans_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.loan_products(id);


--
-- TOC entry 5163 (class 2606 OID 49823)
-- Name: loans loans_target_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_target_account_id_fkey FOREIGN KEY (target_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5164 (class 2606 OID 49828)
-- Name: loans loans_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.loans
    ADD CONSTRAINT loans_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- TOC entry 5180 (class 2606 OID 50050)
-- Name: savings_accounts savings_accounts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.savings_accounts
    ADD CONSTRAINT savings_accounts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- TOC entry 5169 (class 2606 OID 49833)
-- Name: transactions transactions_from_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_from_account_id_fkey FOREIGN KEY (from_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5170 (class 2606 OID 49838)
-- Name: transactions transactions_to_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.transactions
    ADD CONSTRAINT transactions_to_account_id_fkey FOREIGN KEY (to_account_id) REFERENCES public.accounts(id);


--
-- TOC entry 5165 (class 2606 OID 49843)
-- Name: users users_primary_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_primary_account_id_fkey FOREIGN KEY (primary_account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;


-- Completed on 2026-06-03 19:03:12

--
-- PostgreSQL database dump complete
--

\unrestrict EIpcH37whiajKi5CSqYVDzMTYQE0Z1u4TFuX6nYJwVfIRTBNifQy1zZ1okLzQZK


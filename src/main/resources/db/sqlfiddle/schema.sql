--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.1
-- Dumped by pg_dump version 9.6.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: db_types; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE db_types (
    id integer NOT NULL,
    full_name character varying(50),
    simple_name character varying(50),
    setup_script_template text,
    jdbc_class_name character varying(50),
    drop_script_template text,
    custom_jdbc_attributes character varying(100),
    available_environments character varying(500),
    batch_separator character varying(5),
    notes character varying(250),
    sample_fragment character varying(50),
    execution_plan_prefix character varying(500),
    execution_plan_suffix character varying(500),
    execution_plan_xslt text,
    context character varying(10),
    execution_plan_check character varying(300),
    is_latest_stable smallint DEFAULT 0,
    list_database_script character varying(250)
);


ALTER TABLE db_types OWNER TO postgres;

--
-- Name: db_types_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE db_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE db_types_id_seq OWNER TO postgres;

--
-- Name: db_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE db_types_id_seq OWNED BY db_types.id;


--
-- Name: hosts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE hosts (
    id integer NOT NULL,
    db_type_id integer NOT NULL,
    jdbc_url_template character varying(150),
    default_database character varying(50),
    admin_username character varying(50),
    admin_password character varying(50)
);


ALTER TABLE hosts OWNER TO postgres;

--
-- Name: hosts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE hosts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE hosts_id_seq OWNER TO postgres;

--
-- Name: hosts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE hosts_id_seq OWNED BY hosts.id;


--
-- Name: queries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE queries (
    schema_def_id integer,
    environment character varying(100),
    preparation text,
    sql text,
    md5 character varying(32),
    id integer NOT NULL,
    statement_separator character varying(5) DEFAULT ';'::character varying,
    author_id integer
);


ALTER TABLE queries OWNER TO postgres;

--
-- Name: query_sets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE query_sets (
    id integer NOT NULL,
    query_id integer NOT NULL,
    schema_def_id integer,
    row_count integer,
    execution_time integer,
    succeeded smallint,
    sql text,
    execution_plan text,
    error_message text,
    columns_list character varying(500)
);


ALTER TABLE query_sets OWNER TO postgres;

--
-- Name: schema_defs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE schema_defs (
    id integer NOT NULL,
    db_type_id integer NOT NULL,
    short_code character varying(32),
    last_used timestamp without time zone,
    ddl text,
    current_host_id integer,
    md5 character varying(32),
    statement_separator character varying(5) DEFAULT ';'::character varying,
    owner_id integer,
    structure_json text,
    deprovision smallint DEFAULT 1
);


ALTER TABLE schema_defs OWNER TO postgres;

--
-- Name: schema_defs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE schema_defs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE schema_defs_id_seq OWNER TO postgres;

--
-- Name: schema_defs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE schema_defs_id_seq OWNED BY schema_defs.id;


--
-- Name: user_fiddles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE user_fiddles (
    id integer NOT NULL,
    user_id integer NOT NULL,
    schema_def_id integer NOT NULL,
    query_id integer,
    last_accessed timestamp without time zone DEFAULT now(),
    num_accesses integer DEFAULT 1,
    favorite smallint DEFAULT 0
);


ALTER TABLE user_fiddles OWNER TO postgres;

--
-- Name: user_fiddles_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE user_fiddles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE user_fiddles_id_seq OWNER TO postgres;

--
-- Name: user_fiddles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE user_fiddles_id_seq OWNED BY user_fiddles.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE users (
    id integer NOT NULL,
    issuer character varying(1000) NOT NULL,
    subject character varying(1000),
    email character varying(1000)
);


ALTER TABLE users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE users_id_seq OWNED BY users.id;


--
-- Name: db_types id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY db_types ALTER COLUMN id SET DEFAULT nextval('db_types_id_seq'::regclass);


--
-- Name: hosts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hosts ALTER COLUMN id SET DEFAULT nextval('hosts_id_seq'::regclass);


--
-- Name: schema_defs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schema_defs ALTER COLUMN id SET DEFAULT nextval('schema_defs_id_seq'::regclass);


--
-- Name: user_fiddles id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY user_fiddles ALTER COLUMN id SET DEFAULT nextval('user_fiddles_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users ALTER COLUMN id SET DEFAULT nextval('users_id_seq'::regclass);


--
-- Name: db_types db_types_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY db_types
    ADD CONSTRAINT db_types_pkey PRIMARY KEY (id);


--
-- Name: hosts hosts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT hosts_pkey PRIMARY KEY (id);


--
-- Name: queries queries_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY queries
    ADD CONSTRAINT queries_pkey PRIMARY KEY (id);


--
-- Name: query_sets query_sets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY query_sets
    ADD CONSTRAINT query_sets_pkey PRIMARY KEY (id, query_id);


--
-- Name: schema_defs schema_defs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schema_defs
    ADD CONSTRAINT schema_defs_pkey PRIMARY KEY (id);


--
-- Name: user_fiddles user_fiddles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY user_fiddles
    ADD CONSTRAINT user_fiddles_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: query_author; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX query_author ON queries USING btree (author_id);


--
-- Name: query_md5s; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX query_md5s ON queries USING btree (md5, schema_def_id);


--
-- Name: schema_defs_deprovision; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX schema_defs_deprovision ON schema_defs USING btree (short_code, db_type_id) WHERE (deprovision = 0);


--
-- Name: schema_last_used; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX schema_last_used ON schema_defs USING btree (last_used);


--
-- Name: schema_md5s; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX schema_md5s ON schema_defs USING btree (md5, db_type_id);


--
-- Name: schema_owner; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX schema_owner ON schema_defs USING btree (owner_id);


--
-- Name: schema_short_codes; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX schema_short_codes ON schema_defs USING btree (short_code, db_type_id);


--
-- Name: user_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_email ON users USING btree (email);


--
-- Name: user_fiddles_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_fiddles_user_id ON user_fiddles USING btree (user_id);


--
-- Name: user_fiddles_user_schema_query_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX user_fiddles_user_schema_query_id ON user_fiddles USING btree (user_id, schema_def_id, query_id);


--
-- Name: user_identities; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX user_identities ON users USING btree (issuer, subject);


--
-- Name: hosts db_type_ref; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT db_type_ref FOREIGN KEY (db_type_id) REFERENCES db_types(id);


--
-- Name: schema_defs db_type_ref; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY schema_defs
    ADD CONSTRAINT db_type_ref FOREIGN KEY (db_type_id) REFERENCES db_types(id);


--
-- Name: queries schema_def_ref; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY queries
    ADD CONSTRAINT schema_def_ref FOREIGN KEY (schema_def_id) REFERENCES schema_defs(id);


--
-- Name: user_fiddles schema_def_ref; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY user_fiddles
    ADD CONSTRAINT schema_def_ref FOREIGN KEY (schema_def_id) REFERENCES schema_defs(id);


--
-- PostgreSQL database dump complete
--


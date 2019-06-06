--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;

--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: aliases; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE aliases (
    identifier text,
    pki_realm text NOT NULL,
    alias text NOT NULL,
    group_id text,
    generation numeric(49,0),
    notafter numeric(49,0),
    notbefore numeric(49,0)
);

--
-- Name: application_log; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE application_log (
    application_log_id numeric(49,0) NOT NULL,
    logtimestamp numeric(49,0),
    workflow_id numeric(49,0),
    category text,
    priority numeric(49,0),
    message text
);

--
-- Name: audittrail; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE audittrail (
    audittrail_key integer NOT NULL,
    logtimestamp numeric(49,0),
    category text,
    loglevel text,
    message text
);

--
-- Name: certificate; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE certificate (
    pki_realm text,
    issuer_dn text,
    cert_key numeric(49,0) NOT NULL,
    issuer_identifier text NOT NULL,
    identifier text,
    subject text,
    status text,
    subject_key_identifier text,
    authority_key_identifier text,
    notbefore numeric(49,0),
    notafter numeric(49,0),
    revocation_time numeric(49,0),
    invalidity_time numeric(49,0),
    reason_code text,
    hold_instruction_code text,
    req_key numeric(49,0),
    data text,
    role text
);

--
-- Name: certificate_attributes; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE certificate_attributes (
    attribute_key numeric(49,0) NOT NULL,
    identifier text NOT NULL,
    attribute_contentkey text,
    attribute_value text
);

--
-- Name: crl; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE crl (
    pki_realm text NOT NULL,
    issuer_identifier text NOT NULL,
    crl_key numeric(49,0) NOT NULL,
    crl_number numeric(49,0),
    items integer,
    data text,
    last_update numeric(49,0),
    next_update numeric(49,0),
    publication_date numeric(49,0)
);


--
-- Name: csr; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE csr (
    pki_realm text NOT NULL,
    req_key numeric(49,0) NOT NULL,
    format text,
    data text,
    profile text,
    subject text
);

--
-- Name: csr_attributes; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE csr_attributes (
    attribute_key numeric(49,0) NOT NULL,
    pki_realm text NOT NULL,
    req_key numeric(49,0) NOT NULL,
    attribute_contentkey text,
    attribute_value text,
    attribute_source text
);

--
-- Name: datapool; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE datapool (
    pki_realm text NOT NULL,
    namespace text NOT NULL,
    datapool_key text NOT NULL,
    datapool_value text,
    encryption_key text,
    notafter numeric(49,0),
    last_update numeric(49,0)
);

--
-- Name: report; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE report (
    report_name text NOT NULL,
    pki_realm text NOT NULL,
    created numeric(49,0),
    mime_type text NOT NULL,
    description text NOT NULL,
    report_value bytea NOT NULL
);

--
-- Name: secret; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE secret (
    pki_realm text NOT NULL,
    group_id text NOT NULL,
    data text
);

--
-- Name: backend_session; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE backend_session (
    session_id text NOT NULL,
    data text,
    created numeric(49,0) NOT NULL,
    modified numeric(49,0) NOT NULL,
    ip_address text
);

--
-- Name: frontend_session; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE frontend_session (
    session_id text NOT NULL,
    data text,
    created numeric(49,0) NOT NULL,
    modified numeric(49,0) NOT NULL,
    ip_address text
);

--
-- Name: seq_application_log; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_application_log
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_audittrail; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_audittrail
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: audittrail_audittrail_key_seq; Type: SEQUENCE OWNED BY; Schema: public;
--

ALTER SEQUENCE seq_audittrail OWNED BY audittrail.audittrail_key;

--
-- Name: seq_certificate; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_certificate
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_certificate_attributes; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_certificate_attributes
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_crl; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_crl
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_csr; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_csr
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_csr_attributes; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_csr_attributes
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_global_id; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_secret
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_workflow; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_workflow
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: seq_workflow_history; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_workflow_history
    START WITH 0
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;

--
-- Name: workflow; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE workflow (
    workflow_id numeric(49,0) NOT NULL,
    pki_realm text,
    workflow_type text,
    workflow_state text,
    workflow_last_update timestamp without time zone,
    workflow_proc_state text,
    workflow_wakeup_at numeric(49,0),
    workflow_count_try numeric(49,0),
    workflow_reap_at numeric(49,0),
    workflow_session text,
    watchdog_key text
);

--
-- Name: workflow_attributes; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE workflow_attributes (
    workflow_id numeric(49,0) NOT NULL,
    attribute_contentkey text NOT NULL,
    attribute_value text
);

--
-- Name: workflow_context; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE workflow_context (
    workflow_id numeric(49,0) NOT NULL,
    workflow_context_key text NOT NULL,
    workflow_context_value text
);

--
-- Name: workflow_history; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE workflow_history (
    workflow_hist_id numeric(49,0) NOT NULL,
    workflow_id numeric(49,0),
    workflow_action text,
    workflow_description text,
    workflow_state text,
    workflow_user text,
    workflow_node text,
    workflow_history_date timestamp without time zone
);

--
-- Name: ocsp_responses; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE ocsp_responses (
    identifier text,
    serial_number bytea NOT NULL,
    authority_key_identifier bytea NOT NULL,
    body bytea NOT NULL,
    expiry timestamp with time zone
);

--
-- Name: workflow_history; Type: TABLE; Schema: public; Tablespace:
--

ALTER TABLE ONLY ocsp_responses
    ADD CONSTRAINT ocsp_responses_pkey PRIMARY KEY (serial_number, authority_key_identifier);

--
-- Name: audittrail_key; Type: DEFAULT; Schema: public;
--

ALTER TABLE ONLY audittrail ALTER COLUMN audittrail_key SET DEFAULT nextval('seq_audittrail'::regclass);

--
-- Name: aliases_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY aliases
    ADD CONSTRAINT aliases_pkey PRIMARY KEY (pki_realm, alias);

--
-- Name: application_log_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY application_log
    ADD CONSTRAINT application_log_pkey PRIMARY KEY (application_log_id);

--
-- Name: audittrail_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY audittrail
    ADD CONSTRAINT audittrail_pkey PRIMARY KEY (audittrail_key);

--
-- Name: certificate_attributes_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY certificate_attributes
    ADD CONSTRAINT certificate_attributes_pkey PRIMARY KEY (attribute_key, identifier);

--
-- Name: certificate_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY certificate
    ADD CONSTRAINT certificate_pkey PRIMARY KEY (issuer_identifier, cert_key);

--
-- Name: crl_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY crl
    ADD CONSTRAINT crl_pkey PRIMARY KEY (pki_realm, issuer_identifier, crl_key);

--
-- Name: csr_attributes_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY csr_attributes
    ADD CONSTRAINT csr_attributes_pkey PRIMARY KEY (attribute_key, pki_realm, req_key);

--
-- Name: csr_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY csr
    ADD CONSTRAINT csr_pkey PRIMARY KEY (pki_realm, req_key);

--
-- Name: datapool_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY datapool
    ADD CONSTRAINT datapool_pkey PRIMARY KEY (pki_realm, namespace, datapool_key);

--
-- Name: secret_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY secret
    ADD CONSTRAINT secret_pkey PRIMARY KEY (pki_realm, group_id);

--
-- Name: backend_session_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY backend_session
    ADD CONSTRAINT backend_session_pkey PRIMARY KEY (session_id);

--
-- Name: frontend_session_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY frontend_session
    ADD CONSTRAINT frontend_session_pkey PRIMARY KEY (session_id);

--
-- Name: workflow_attributes_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY workflow_attributes
    ADD CONSTRAINT workflow_attributes_pkey PRIMARY KEY (workflow_id, attribute_contentkey);

--
-- Name: workflow_context_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY workflow_context
    ADD CONSTRAINT workflow_context_pkey PRIMARY KEY (workflow_id, workflow_context_key);

--
-- Name: workflow_history_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY workflow_history
    ADD CONSTRAINT workflow_history_pkey PRIMARY KEY (workflow_hist_id);

--
-- Name: workflow_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY workflow
    ADD CONSTRAINT workflow_pkey PRIMARY KEY (workflow_id);


CREATE INDEX aliases_realm_group ON aliases USING btree (pki_realm, group_id);

CREATE INDEX application_log_id ON application_log USING btree (workflow_id);
CREATE INDEX application_log_filter ON application_log USING btree (workflow_id,category,priority);

CREATE INDEX cert_csr_serial_index ON certificate USING btree (req_key);
CREATE UNIQUE INDEX cert_identifier_index ON certificate USING btree (identifier);
CREATE INDEX cert_issuer_identifier_index ON certificate USING btree (issuer_identifier);
CREATE INDEX cert_realm_req_index ON certificate USING btree (pki_realm, req_key);
CREATE INDEX cert_realm_index ON certificate USING btree (pki_realm);
CREATE INDEX cert_status_index ON certificate USING btree (status);
CREATE INDEX cert_subject_index ON certificate USING btree (subject);
CREATE INDEX cert_notbefore_index ON certificate USING btree (notbefore);
CREATE INDEX cert_notafter_index ON certificate USING btree (notafter);
CREATE INDEX cert_revocation_time_index ON certificate USING btree (revocation_time);
CREATE INDEX cert_invalidity_time_index ON certificate USING btree (invalidity_time);
CREATE INDEX cert_reason_code_index ON certificate USING btree (reason_code);
CREATE INDEX cert_hold_index ON certificate USING btree (hold_instruction_code);

CREATE INDEX cert_attributes_key_index ON certificate_attributes USING btree (attribute_contentkey);
CREATE INDEX cert_attributes_value_index ON certificate_attributes USING btree (attribute_value);
CREATE INDEX cert_attributes_identifier_index ON certificate_attributes USING btree (identifier);
CREATE INDEX cert_attributes_keyid_index ON certificate_attributes USING btree (identifier,attribute_contentkey);
CREATE INDEX cert_attributes_keyvalue_index ON certificate_attributes USING btree (attribute_contentkey,attribute_value);


CREATE INDEX crl_issuer_index ON crl USING btree (issuer_identifier);
CREATE INDEX crl_realm_index ON crl USING btree (pki_realm);
CREATE INDEX crl_issuer_update_index ON crl USING btree (issuer_identifier, last_update);
CREATE INDEX crl_issuer_number_index ON crl USING btree (issuer_identifier, crl_number);

CREATE INDEX csr_subject_index ON csr USING btree (subject);
CREATE INDEX csr_realm_index ON csr USING btree (pki_realm);
CREATE INDEX csr_realm_profile_index ON csr USING btree (pki_realm, profile);

CREATE INDEX csr_attributes_req_key_index ON csr_attributes USING btree (req_key);

CREATE INDEX datapool_namespace_index ON datapool USING btree (pki_realm, namespace);
CREATE INDEX datapool_notafter_index ON datapool USING btree (notafter);

CREATE INDEX backend_session_modified_index ON backend_session USING btree (modified);

CREATE INDEX frontend_session_modified_index ON frontend_session USING btree (modified);

CREATE INDEX workflow_pki_realm_index ON workflow USING btree (pki_realm);
CREATE INDEX workflow_realm_type_index ON workflow USING btree (pki_realm, workflow_type);
CREATE INDEX workflow_state_index ON workflow USING btree (pki_realm, workflow_state);
CREATE INDEX workflow_state_index ON workflow USING btree (pki_realm, workflow_proc_state);
CREATE INDEX workflow_wakeup_index ON workflow USING btree (workflow_proc_state, watchdog_key, workflow_wakeup_at);
CREATE INDEX workflow_reapat_index ON workflow USING btree (workflow_proc_state, watchdog_key, workflow_reap_at);

CREATE INDEX wfl_attributes_id_index ON workflow_attributes USING btree (workflow_id);
CREATE INDEX wfl_attributes_key_index ON workflow_attributes USING btree (attribute_contentkey);
CREATE INDEX wfl_attributes_value_index ON workflow_attributes USING btree (attribute_value);
CREATE INDEX wfl_attributes_keyvalue_index ON workflow_attributes USING btree (attribute_contentkey,attribute_value);

CREATE INDEX wf_hist_wfserial_index ON workflow_history USING btree (workflow_id);

CREATE INDEX ocsp_responses_index ON ocsp_responses USING btree (identifier);

--
-- PostgreSQL database dump complete
--

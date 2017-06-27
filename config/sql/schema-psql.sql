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
    notafter numeric(49,0),
    loa text,
    notbefore numeric(49,0),
    req_key numeric(49,0),
    public_key text,
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
    data text,
    last_update numeric(49,0),
    next_update numeric(49,0),
    publication_date numeric(49,0)
);

--
-- Name: crr; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE crr (
    crr_key numeric(49,0) NOT NULL,
    pki_realm text NOT NULL,
    identifier text NOT NULL,
    creator text,
    creator_role text,
    reason_code text,
    invalidity_time numeric(49,0),
    crr_comment text,
    hold_code text,
    revocation_time numeric(49,0)
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
    loa text,
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
    report_value bytea NOT NULL,
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
-- Name: session; Type: TABLE; Schema: public; Tablespace:
--

CREATE TABLE session (
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
-- Name: seq_crr; Type: SEQUENCE; Schema: public;
--

CREATE SEQUENCE seq_crr
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
    workflow_history_date timestamp without time zone
);

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
-- Name: crr_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY crr
    ADD CONSTRAINT crr_pkey PRIMARY KEY (crr_key, pki_realm, identifier);

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
-- Name: session_pkey; Type: CONSTRAINT; Schema: public; Tablespace:
--

ALTER TABLE ONLY session
    ADD CONSTRAINT session_pkey PRIMARY KEY (session_id);

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

--
-- Name: cert_attributes_key_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_attributes_key_index ON certificate_attributes USING btree (attribute_contentkey);

--
-- Name: cert_csr_serial_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_csr_serial_index ON certificate USING btree (req_key);

--
-- Name: cert_csrid_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_csrid_index ON certificate USING btree (req_key);

--
-- Name: cert_identifier_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_identifier_index ON certificate USING btree (identifier);

--
-- Name: cert_pki_realm_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_pki_realm_index ON certificate USING btree (pki_realm);

--
-- Name: cert_realm_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_realm_index ON certificate USING btree (pki_realm);

--
-- Name: cert_status_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_status_index ON certificate USING btree (status);

--
-- Name: cert_subject_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX cert_subject_index ON certificate USING btree (subject);

--
-- Name: csr_profile_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX csr_profile_index ON csr USING btree (profile);

--
-- Name: csr_subject_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX csr_subject_index ON csr USING btree (subject);

--
-- Name: session_modified_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX session_modified_index ON session USING btree (modified);

--
-- Name: wf_attributes_key_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX wf_attributes_key_index ON workflow_attributes USING btree (workflow_id);

--
-- Name: wf_context_key_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX wf_context_key_index ON workflow_context USING btree (workflow_context_key);

--
-- Name: wf_hist_wfserial_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX wf_hist_wfserial_index ON workflow_history USING btree (workflow_id);

--
-- Name: wf_realm_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX wf_realm_index ON workflow USING btree (pki_realm);

--
-- Name: workflow_history_workflow_serial_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX workflow_history_workflow_serial_index ON workflow_history USING btree (workflow_id);

--
-- Name: workflow_pki_realm_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX workflow_pki_realm_index ON workflow USING btree (pki_realm);

--
-- Name: workflow_state_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX workflow_state_index ON workflow USING btree (workflow_state);

--
-- Name: workflow_type_index; Type: INDEX; Schema: public; Tablespace:
--

CREATE INDEX workflow_type_index ON workflow USING btree (workflow_type);

--
-- PostgreSQL database dump complete
--

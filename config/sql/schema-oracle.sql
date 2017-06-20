--
-- Created by SQL::Translator::Producer::Oracle
-- Created on Thu Nov  3 23:31:57 2016
--
--
-- Table: aliases
--;

DROP TABLE aliases CASCADE CONSTRAINTS;

CREATE TABLE aliases (
  identifier varchar2(64),
  pki_realm varchar2(255) NOT NULL,
  alias varchar2(255) NOT NULL,
  group_id varchar2(255),
  generation number,
  notafter number,
  notbefore number,
  PRIMARY KEY (pki_realm, alias)
);

--
-- Table: application_log
--;

DROP TABLE application_log CASCADE CONSTRAINTS;

CREATE TABLE application_log (
  application_log_id number NOT NULL,
  logtimestamp number,
  workflow_id number(38,0) NOT NULL,
  priority number DEFAULT '0',
  category varchar2(255) NOT NULL,
  message clob,
  PRIMARY KEY (application_log_id)
);

--
-- Table: audittrail
--;

DROP TABLE audittrail CASCADE CONSTRAINTS;

DROP SEQUENCE sq_audittrail_audittrail_key;

CREATE SEQUENCE sq_audittrail_audittrail_key;

CREATE TABLE audittrail (
  audittrail_key number NOT NULL,
  logtimestamp number,
  category varchar2(255),
  loglevel varchar2(255),
  message clob,
  PRIMARY KEY (audittrail_key)
);

--
-- Table: certificate
--;

DROP TABLE certificate CASCADE CONSTRAINTS;

CREATE TABLE certificate (
  pki_realm varchar2(255),
  issuer_dn varchar2(1000),
  cert_key number(38,0) NOT NULL,
  issuer_identifier varchar2(64) NOT NULL,
  identifier varchar2(64),
  subject varchar2(1000),
  status varchar2(255),
  subject_key_identifier varchar2(255),
  authority_key_identifier varchar2(255),
  notbefore number,
  notafter number,
  loa varchar2(255),
  req_key number,
  public_key clob,
  data clob,
  PRIMARY KEY (issuer_identifier, cert_key)
);

--
-- Table: certificate_attributes
--;

DROP TABLE certificate_attributes CASCADE CONSTRAINTS;

CREATE TABLE certificate_attributes (
  identifier varchar2(64) NOT NULL,
  attribute_key number NOT NULL,
  attribute_contentkey varchar2(255),
  attribute_value varchar2(4000),
  PRIMARY KEY (attribute_key, identifier)
);

--
-- Table: crl
--;

DROP TABLE crl CASCADE CONSTRAINTS;

CREATE TABLE crl (
  pki_realm varchar2(255) NOT NULL,
  issuer_identifier varchar2(64) NOT NULL,
  crl_key number(38,0) NOT NULL,
  data clob,
  last_update number,
  next_update number,
  publication_date number,
  PRIMARY KEY (issuer_identifier, crl_key)
);

--
-- Table: crr
--;

DROP TABLE crr CASCADE CONSTRAINTS;

CREATE TABLE crr (
  crr_key number NOT NULL,
  pki_realm varchar2(255) NOT NULL,
  identifier varchar2(64) NOT NULL,
  creator varchar2(255),
  creator_role varchar2(255),
  reason_code varchar2(255),
  invalidity_time number,
  crr_comment clob,
  hold_code varchar2(255),
  revocation_time number,
  PRIMARY KEY (pki_realm, crr_key)
);

--
-- Table: csr
--;

DROP TABLE csr CASCADE CONSTRAINTS;

CREATE TABLE csr (
  req_key number NOT NULL,
  pki_realm varchar2(255) NOT NULL,
  format varchar2(25),
  profile varchar2(255),
  loa varchar2(255),
  subject varchar2(1000),
  data clob,
  PRIMARY KEY (pki_realm, req_key)
);

--
-- Table: csr_attributes
--;

DROP TABLE csr_attributes CASCADE CONSTRAINTS;

CREATE TABLE csr_attributes (
  attribute_key number NOT NULL,
  pki_realm varchar2(255) NOT NULL,
  req_key number(38,0) NOT NULL,
  attribute_contentkey varchar2(255),
  attribute_value clob,
  attribute_source clob,
  PRIMARY KEY (attribute_key, pki_realm, req_key)
);

--
-- Table: datapool
--;

DROP TABLE datapool CASCADE CONSTRAINTS;

CREATE TABLE datapool (
  pki_realm varchar2(255) NOT NULL,
  namespace varchar2(255) NOT NULL,
  datapool_key varchar2(255) NOT NULL,
  datapool_value clob,
  encryption_key varchar2(255),
  notafter number,
  last_update number,
  PRIMARY KEY (pki_realm, namespace, datapool_key)
);

--
-- Table: report
--;

create table REPORT (
  report_name varchar2(63),
  pki_realm varchar2(255),
  created number(38), -- unix timestamp
  mime_type varchar2(63), -- advisory, e.g. text/csv, text/plain, application/pdf, ...
  description varchar2(255),
  report_value clob,
  primary key ("report_name", "pki_realm")
);

--
-- Table: secret
--;

DROP TABLE secret CASCADE CONSTRAINTS;

CREATE TABLE secret (
  pki_realm varchar2(255) NOT NULL,
  group_id varchar2(255) NOT NULL,
  data clob,
  PRIMARY KEY (pki_realm, group_id)
);

--
-- Table: session
--;

DROP TABLE session CASCADE CONSTRAINTS;

CREATE TABLE session (
  session_id varchar2(255) NOT NULL,
  data clob,
  created number NOT NULL,
  modified number NOT NULL,
  ip_address varchar2(45),
  PRIMARY KEY (session_id)
);

--
-- Table: workflow
--;

DROP TABLE workflow CASCADE CONSTRAINTS;

CREATE TABLE workflow (
  workflow_id number NOT NULL,
  pki_realm varchar2(255),
  workflow_type varchar2(255),
  workflow_state varchar2(255),
  workflow_last_update date DEFAULT current_timestamp NOT NULL,
  workflow_proc_state varchar2(32),
  workflow_wakeup_at number,
  workflow_count_try number,
  workflow_reap_at number,
  workflow_session clob,
  watchdog_key varchar2(64),
  PRIMARY KEY (workflow_id)
);

--
-- Table: workflow_attributes
--;

DROP TABLE workflow_attributes CASCADE CONSTRAINTS;

CREATE TABLE workflow_attributes (
  workflow_id number NOT NULL,
  attribute_contentkey varchar2(255) NOT NULL,
  attribute_value varchar2(4000),
  PRIMARY KEY (workflow_id, attribute_contentkey)
);

--
-- Table: workflow_context
--;

DROP TABLE workflow_context CASCADE CONSTRAINTS;

CREATE TABLE workflow_context (
  workflow_id number NOT NULL,
  workflow_context_key varchar2(255) NOT NULL,
  workflow_context_value clob,
  PRIMARY KEY (workflow_id, workflow_context_key)
);

--
-- Table: workflow_history
--;

DROP TABLE workflow_history CASCADE CONSTRAINTS;

CREATE TABLE workflow_history (
  workflow_hist_id number NOT NULL,
  workflow_id number,
  workflow_action varchar2(255),
  workflow_description clob,
  workflow_state varchar2(255),
  workflow_user varchar2(255),
  workflow_history_date date DEFAULT current_timestamp NOT NULL,
  PRIMARY KEY (workflow_hist_id)
);

CREATE OR REPLACE TRIGGER ai_audittrail_audittrail_key
BEFORE INSERT ON audittrail
FOR EACH ROW WHEN (
 new.audittrail_key IS NULL OR new.audittrail_key = 0
)
BEGIN
 SELECT sq_audittrail_audittrail_key.nextval
 INTO :new.audittrail_key
 FROM dual;
END;
/

CREATE OR REPLACE TRIGGER ts_workflow_workflow_last_upda
BEFORE INSERT OR UPDATE ON workflow
FOR EACH ROW WHEN (new.workflow_last_update IS NULL)
BEGIN
 SELECT sysdate INTO :new.workflow_last_update FROM dual;
END;
/

CREATE OR REPLACE TRIGGER ts_workflow_history_workflow_h
BEFORE INSERT OR UPDATE ON workflow_history
FOR EACH ROW WHEN (new.workflow_history_date IS NULL)
BEGIN
 SELECT sysdate INTO :new.workflow_history_date FROM dual;
END;
/

DROP SEQUENCE seq_application_log;
CREATE SEQUENCE seq_application_log START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_audittrail;
CREATE SEQUENCE seq_audittrail START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_certificate;
CREATE SEQUENCE seq_certificate START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_certificate_attributes;
CREATE SEQUENCE seq_certificate_attributes START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_crl;
CREATE SEQUENCE seq_crl START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_crr;
CREATE SEQUENCE seq_crr START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_csr;
CREATE SEQUENCE seq_csr START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_csr_attributes;
CREATE SEQUENCE seq_csr_attributes START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_secret;
CREATE SEQUENCE seq_secret START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_workflow;
CREATE SEQUENCE seq_workflow START WITH 0 INCREMENT BY 1 MINVALUE 0;
DROP SEQUENCE seq_workflow_history;
CREATE SEQUENCE seq_workflow_history START WITH 0 INCREMENT BY 1 MINVALUE 0;

QUIT;

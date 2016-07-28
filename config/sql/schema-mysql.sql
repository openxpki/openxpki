SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

CREATE TABLE IF NOT EXISTS `aliases` (
  `identifier` varchar(64) DEFAULT NULL,
  `pki_realm` varchar(255) NOT NULL,
  `alias` varchar(255) NOT NULL,
  `group_id` varchar(255) DEFAULT NULL,
  `generation` smallint(6) DEFAULT NULL,
  `notafter` int(10) unsigned DEFAULT NULL,
  `notbefore` int(10) unsigned DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `application_log` (
  `application_log_id` bigint(20) unsigned NOT NULL,
  `logtimestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `workflow_id` decimal(49,0) NOT NULL,
  `priority` int(11) DEFAULT '0',
  `category` varchar(255) NOT NULL,
  `message` longtext
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `audittrail` (
  `audittrail_key` bigint(20) unsigned NOT NULL,
  `logtimestamp` int(10) unsigned DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL,
  `loglevel` varchar(255) DEFAULT NULL,
  `message` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `certificate` (
  `pki_realm` varchar(255) DEFAULT NULL,
  `issuer_dn` varchar(1000) DEFAULT NULL,
  `cert_key` decimal(49,0) NOT NULL,
  `issuer_identifier` varchar(64) NOT NULL,
  `identifier` varchar(64) DEFAULT NULL,
  `subject` varchar(1000) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `subject_key_identifier` varchar(255) DEFAULT NULL,
  `authority_key_identifier` varchar(255) DEFAULT NULL,
  `notbefore` int(10) unsigned DEFAULT NULL,
  `notafter` int(10) unsigned DEFAULT NULL,
  `loa` varchar(255) DEFAULT NULL,
  `req_key` bigint(20) unsigned DEFAULT NULL,
  `public_key` text,
  `data` longtext
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `certificate_attributes` (
  `identifier` varchar(64) NOT NULL,
  `attribute_key` bigint(20) unsigned NOT NULL,
  `attribute_contentkey` varchar(255) DEFAULT NULL,
  `attribute_value` varchar(4000) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `crl` (
  `pki_realm` varchar(255) NOT NULL,
  `issuer_identifier` varchar(64) NOT NULL,
  `crl_key` decimal(49,0) NOT NULL,
  `data` longtext,
  `last_update` int(10) unsigned DEFAULT NULL,
  `next_update` int(10) unsigned DEFAULT NULL,
  `publication_date` int(10) unsigned DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `crr` (
  `crr_key` bigint(20) unsigned NOT NULL,
  `pki_realm` varchar(255) NOT NULL,
  `identifier` varchar(64) NOT NULL,
  `creator` varchar(255) DEFAULT NULL,
  `creator_role` varchar(255) DEFAULT NULL,
  `reason_code` varchar(255) DEFAULT NULL,
  `invalidity_time` int(10) unsigned DEFAULT NULL,
  `crr_comment` text,
  `hold_code` varchar(255) DEFAULT NULL,
  `revocation_time` int(10) unsigned DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `csr` (
  `req_key` bigint(20) unsigned NOT NULL,
  `pki_realm` varchar(255) NOT NULL,
  `format` varchar(25) DEFAULT NULL,
  `profile` varchar(255) DEFAULT NULL,
  `loa` varchar(255) DEFAULT NULL,
  `subject` varchar(1000) DEFAULT NULL,
  `data` longtext
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `csr_attributes` (
  `attribute_key` bigint(20) unsigned NOT NULL,
  `pki_realm` varchar(255) NOT NULL,
  `req_key` decimal(49,0) NOT NULL,
  `attribute_contentkey` varchar(255) DEFAULT NULL,
  `attribute_value` longtext,
  `attribute_source` text
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `datapool` (
  `pki_realm` varchar(255) NOT NULL,
  `namespace` varchar(255) NOT NULL,
  `datapool_key` varchar(255) NOT NULL,
  `datapool_value` longtext,
  `encryption_key` varchar(255) DEFAULT NULL,
  `notafter` int(10) unsigned DEFAULT NULL,
  `last_update` int(10) unsigned DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `secret` (
  `pki_realm` varchar(255) NOT NULL,
  `group_id` varchar(255) NOT NULL,
  `data` longtext
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_application_log` (
  `seq_number` bigint(20) unsigned NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_audittrail` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_certificate` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_certificate_attributes` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_crl` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_crr` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_csr` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_csr_attributes` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_secret` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_workflow` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `seq_workflow_history` (
  `seq_number` bigint(20) NOT NULL,
  `dummy` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `workflow` (
  `workflow_id` bigint(20) unsigned NOT NULL,
  `pki_realm` varchar(255) DEFAULT NULL,
  `workflow_type` varchar(255) DEFAULT NULL,
  `workflow_state` varchar(255) DEFAULT NULL,
  `workflow_last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `workflow_proc_state` varchar(32) DEFAULT NULL,
  `workflow_wakeup_at` int(10) unsigned DEFAULT NULL,
  `workflow_count_try` int(10) unsigned DEFAULT NULL,
  `workflow_reap_at` int(10) unsigned DEFAULT NULL,
  `workflow_session` longtext,
  `watchdog_key` varchar(64) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `workflow_attributes` (
  `workflow_id` bigint(20) unsigned NOT NULL,
  `attribute_contentkey` varchar(255) NOT NULL,
  `attribute_value` varchar(4000) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `workflow_context` (
  `workflow_id` bigint(20) unsigned NOT NULL,
  `workflow_context_key` varchar(255) NOT NULL,
  `workflow_context_value` longtext
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `workflow_history` (
  `workflow_hist_id` bigint(20) unsigned NOT NULL,
  `workflow_id` bigint(20) unsigned DEFAULT NULL,
  `workflow_action` varchar(255) DEFAULT NULL,
  `workflow_description` longtext,
  `workflow_state` varchar(255) DEFAULT NULL,
  `workflow_user` varchar(255) DEFAULT NULL,
  `workflow_history_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;


ALTER TABLE `aliases`
 ADD PRIMARY KEY (`pki_realm`,`alias`);

ALTER TABLE `application_log`
 ADD PRIMARY KEY (`application_log_id`), ADD KEY `workflow_id` (`workflow_id`), ADD KEY `workflow_id_2` (`workflow_id`,`category`,`priority`);

ALTER TABLE `audittrail`
 ADD PRIMARY KEY (`audittrail_key`);

ALTER TABLE `certificate`
 ADD PRIMARY KEY (`issuer_identifier`,`cert_key`), ADD KEY `pki_realm` (`pki_realm`), ADD KEY `identifier` (`identifier`), ADD KEY `issuer_identifier` (`issuer_identifier`), ADD KEY `subject` (`subject`(255)), ADD KEY `status` (`status`), ADD KEY `pki_realm_2` (`pki_realm`,`req_key`), ADD KEY `notbefore` (`notbefore`), ADD KEY `notafter` (`notafter`);

ALTER TABLE `certificate_attributes`
 ADD PRIMARY KEY (`attribute_key`,`identifier`), ADD KEY `attribute_contentkey` (`attribute_contentkey`), ADD KEY `attribute_value` (`attribute_value`(255)), ADD KEY `identifier` (`identifier`), ADD KEY `identifier_2` (`identifier`,`attribute_contentkey`), ADD KEY `attribute_contentkey_2` (`attribute_contentkey`,`attribute_value`(255));

ALTER TABLE `crl`
 ADD PRIMARY KEY (`issuer_identifier`,`crl_key`), ADD KEY `issuer_identifier` (`issuer_identifier`), ADD KEY `pki_realm` (`pki_realm`), ADD KEY `issuer_identifier_2` (`issuer_identifier`,`last_update`);

ALTER TABLE `crr`
 ADD PRIMARY KEY (`pki_realm`,`crr_key`), ADD KEY `identifier` (`identifier`), ADD KEY `pki_realm` (`pki_realm`), ADD KEY `creator` (`creator`);

ALTER TABLE `csr`
 ADD PRIMARY KEY (`pki_realm`,`req_key`), ADD KEY `pki_realm` (`pki_realm`), ADD KEY `profile` (`profile`), ADD KEY `subject` (`subject`(255));

ALTER TABLE `csr_attributes`
 ADD PRIMARY KEY (`attribute_key`,`pki_realm`,`req_key`), ADD KEY `attribute_contentkey` (`attribute_contentkey`), ADD KEY `req_key` (`req_key`), ADD KEY `attribute_contentkey_2` (`attribute_contentkey`,`req_key`), ADD KEY `pki_realm` (`pki_realm`);

ALTER TABLE `datapool`
 ADD PRIMARY KEY (`pki_realm`,`namespace`,`datapool_key`), ADD KEY `pki_realm` (`pki_realm`,`namespace`), ADD KEY `notafter` (`notafter`);

ALTER TABLE `secret`
 ADD PRIMARY KEY (`pki_realm`,`group_id`);

ALTER TABLE `seq_application_log`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_audittrail`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_certificate`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_certificate_attributes`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_crl`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_crr`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_csr`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_csr_attributes`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_secret`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_workflow`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `seq_workflow_history`
 ADD PRIMARY KEY (`seq_number`);

ALTER TABLE `workflow`
 ADD PRIMARY KEY (`workflow_id`), ADD KEY `workflow_state` (`workflow_state`), ADD KEY `pki_realm` (`pki_realm`), ADD KEY `pki_realm_2` (`pki_realm`,`workflow_type`), ADD KEY `workflow_proc_state` (`workflow_proc_state`,`workflow_wakeup_at`), ADD KEY `workflow_proc_state_2` (`workflow_proc_state`,`workflow_reap_at`), ADD KEY `pki_realm_3` (`pki_realm`,`workflow_state`), ADD KEY `pki_realm_4` (`pki_realm`,`workflow_proc_state`);

ALTER TABLE `workflow_attributes`
 ADD PRIMARY KEY (`workflow_id`,`attribute_contentkey`), ADD KEY `workflow_id` (`workflow_id`), ADD KEY `attribute_contentkey` (`attribute_contentkey`), ADD KEY `attribute_value` (`attribute_value`(255)), ADD KEY `attribute_contentkey_2` (`attribute_contentkey`,`attribute_value`(255));

ALTER TABLE `workflow_context`
 ADD PRIMARY KEY (`workflow_id`,`workflow_context_key`);

ALTER TABLE `workflow_history`
 ADD PRIMARY KEY (`workflow_hist_id`), ADD KEY `workflow_id` (`workflow_id`);


ALTER TABLE `audittrail`
MODIFY `audittrail_key` bigint(20) unsigned NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_application_log`
MODIFY `seq_number` bigint(20) unsigned NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_audittrail`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_certificate`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_certificate_attributes`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_crl`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_crr`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_csr`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_csr_attributes`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_secret`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_workflow`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;
ALTER TABLE `seq_workflow_history`
MODIFY `seq_number` bigint(20) NOT NULL AUTO_INCREMENT;

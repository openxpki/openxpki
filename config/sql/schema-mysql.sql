SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `openxpki`
--

-- --------------------------------------------------------

--
-- Table structure for table `aliases`
--

DROP TABLE IF EXISTS `aliases`;
CREATE TABLE IF NOT EXISTS `aliases` (
  `identifier` varchar(64) DEFAULT NULL,
  `pki_realm` varchar(255) NOT NULL,
  `alias` varchar(255) NOT NULL,
  `group_id` varchar(255) DEFAULT NULL,
  `generation` smallint DEFAULT NULL,
  `notafter` int unsigned, 
  `notbefore` int unsigned, 
  PRIMARY KEY (`pki_realm`,`alias`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `audittrail`
--

DROP TABLE IF EXISTS `audittrail`;
CREATE TABLE IF NOT EXISTS `audittrail` (
  `audittrail_key` bigint unsigned NOT NULL AUTO_INCREMENT,
  `logtimestamp` int unsigned DEFAULT NULL,
  `category` varchar(255) DEFAULT NULL,
  `loglevel` varchar(255) DEFAULT NULL,
  `message` text,
  PRIMARY KEY (`audittrail_key`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `certificate`
--

DROP TABLE IF EXISTS `certificate`;
CREATE TABLE IF NOT EXISTS `certificate` (
  `pki_realm` varchar(255) DEFAULT NULL,
  `issuer_dn` varchar(1000) DEFAULT NULL,
  `cert_key` decimal(49,0) NOT NULL,
  `issuer_identifier` varchar(64) NOT NULL,
  `identifier` varchar(64) DEFAULT NULL,
  `data` longtext,
  `subject` varchar(1000) DEFAULT NULL,
  `status` varchar(255) DEFAULT NULL,
  `public_key` text,
  `subject_key_identifier` varchar(255) DEFAULT NULL,
  `authority_key_identifier` varchar(255) DEFAULT NULL,
  `notbefore` int unsigned DEFAULT NULL,
  `notafter` int unsigned DEFAULT NULL,
  `loa` varchar(255) DEFAULT NULL,
  `req_key` bigint unsigned DEFAULT NULL,
  PRIMARY KEY (`issuer_identifier`,`cert_key`),
  KEY (`pki_realm`),
  KEY (`identifier`),
  KEY (`issuer_identifier`),
  KEY (`subject`),
  KEY (`status`),
  KEY (`pki_realm`,`req_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `certificate_attributes`
--

DROP TABLE IF EXISTS `certificate_attributes`;
CREATE TABLE IF NOT EXISTS `certificate_attributes` (
  `attribute_key` bigint unsigned NOT NULL,
  `identifier` varchar(64) NOT NULL,
  `attribute_contentkey` varchar(255) DEFAULT NULL,
  `attribute_value` varchar(4000),
  PRIMARY KEY (`attribute_key`,`identifier`),
  KEY (`attribute_contentkey`),
  KEY (`attribute_value`),
  KEY (`identifier`),
  KEY (`identifier`,`attribute_contentkey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `crl`
--

DROP TABLE IF EXISTS `crl`;
CREATE TABLE IF NOT EXISTS `crl` (
  `pki_realm` varchar(255) NOT NULL,
  `issuer_identifier` varchar(64) NOT NULL,
  `crl_key` decimal(49,0) NOT NULL,
  `data` longtext,
  `last_update` int unsigned DEFAULT NULL,
  `next_update` int unsigned DEFAULT NULL,
  `publication_date` int unsigned DEFAULT NULL,
  PRIMARY KEY (`issuer_identifier`,`crl_key`),
  KEY (`issuer_identifier`),
  KEY (`pki_realm`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `crr`
--

DROP TABLE IF EXISTS `crr`;
CREATE TABLE IF NOT EXISTS `crr` (
  `crr_key` bigint unsigned NOT NULL,
  `pki_realm` varchar(255) NOT NULL,
  `identifier` varchar(64) NOT NULL,
  `creator` varchar(255) DEFAULT NULL,
  `creator_role` varchar(255) DEFAULT NULL,
  `reason_code` varchar(255) DEFAULT NULL,
  `invalidity_time` int unsigned DEFAULT NULL,
  `crr_comment` text,
  `hold_code` varchar(255) DEFAULT NULL,
  `revocation_time` int unsigned DEFAULT NULL,
  PRIMARY KEY (`pki_realm`,`crr_key`),
  KEY (`identifier`),
  KEY (`pki_realm`),
  KEY (`creator`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `csr`
--

DROP TABLE IF EXISTS `csr`;
CREATE TABLE IF NOT EXISTS `csr` (
  `pki_realm` varchar(255) NOT NULL,
  `req_key` bigint unsigned NOT NULL,
  `format` varchar(25),
  `data` longtext,
  `profile` varchar(255) DEFAULT NULL,
  `loa` varchar(255) DEFAULT NULL,
  `subject` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`pki_realm`,`req_key`),
  KEY (`pki_realm`),
  KEY (`profile`),
  KEY (`subject`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `csr_attributes`
--

DROP TABLE IF EXISTS `csr_attributes`;
CREATE TABLE IF NOT EXISTS `csr_attributes` (
  `attribute_key` bigint unsigned NOT NULL,
  `pki_realm` varchar(255) NOT NULL,
  `req_key` decimal(49,0) NOT NULL,
  `attribute_contentkey` varchar(255) DEFAULT NULL,
  `attribute_value` longtext,
  `attribute_source` text,
  PRIMARY KEY (`attribute_key`,`pki_realm`,`req_key`),
  KEY (`attribute_contentkey`),
  KEY (`req_key`),
  KEY (`attribute_contentkey`,`req_key`),
  KEY (`pki_realm`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `datapool`
--

DROP TABLE IF EXISTS `datapool`;
CREATE TABLE IF NOT EXISTS `datapool` (
  `pki_realm` varchar(255) NOT NULL,
  `namespace` varchar(255) NOT NULL,
  `datapool_key` varchar(255) NOT NULL,
  `datapool_value` text,
  `encryption_key` varchar(255) DEFAULT NULL,
  `notafter` decimal(49,0) DEFAULT NULL,
  `last_update` decimal(49,0) DEFAULT NULL,
  PRIMARY KEY (`pki_realm`,`namespace`,`datapool_key`),
  KEY (`pki_realm`,`namespace`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `secret`
--

DROP TABLE IF EXISTS `secret`;
CREATE TABLE IF NOT EXISTS `secret` (
  `pki_realm` varchar(255) NOT NULL,
  `group_id` varchar(255) NOT NULL,
  `data` longtext,
  PRIMARY KEY (`pki_realm`,`group_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------
 
--
-- Table structure for table `workflow`
--

DROP TABLE IF EXISTS `workflow`;
CREATE TABLE IF NOT EXISTS `workflow` (
  `workflow_id` bigint unsigned NOT NULL,
  `pki_realm` varchar(255) DEFAULT NULL,
  `workflow_type` varchar(255) DEFAULT NULL,
  `workflow_state` varchar(255) DEFAULT NULL,
  `workflow_last_update` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `workflow_proc_state` varchar(32),
  `workflow_wakeup_at` int unsigned DEFAULT NULL,
  `workflow_count_try` int unsigned DEFAULT NULL,
  `workflow_reap_at` int unsigned DEFAULT NULL,
  `workflow_session` longtext,
  `watchdog_key` varchar(64),
  PRIMARY KEY (`workflow_id`),
  KEY (`workflow_state`),
  KEY (`pki_realm`),
  KEY (`workflow_type`),
  KEY (`workflow_proc_state`,`workflow_wakeup_at`),
  KEY (`workflow_proc_state`,`workflow_reap_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `workflow_attributes`
--

DROP TABLE IF EXISTS `workflow_attributes`;
CREATE TABLE IF NOT EXISTS `workflow_attributes` (
  `workflow_id` bigint unsigned NOT NULL,
  `attribute_contentkey` varchar(255) NOT NULL,
  `attribute_value` varchar(4000),
  PRIMARY KEY (`workflow_id`,`attribute_contentkey`),
  KEY (`workflow_id`),
  KEY (`attribute_contentkey`),
  KEY (`attribute_value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `workflow_context`
--

DROP TABLE IF EXISTS `workflow_context`;
CREATE TABLE IF NOT EXISTS `workflow_context` (
  `workflow_id` bigint unsigned NOT NULL,
  `workflow_context_key` varchar(255) NOT NULL,
  `workflow_context_value` longtext,
  PRIMARY KEY (`workflow_id`,`workflow_context_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `workflow_history`
--

DROP TABLE IF EXISTS `workflow_history`;
CREATE TABLE IF NOT EXISTS `workflow_history` (
  `workflow_hist_id` bigint unsigned NOT NULL,
  `workflow_id` bigint unsigned DEFAULT NULL,
  `workflow_action` varchar(255) DEFAULT NULL,
  `workflow_description` longtext DEFAULT NULL,
  `workflow_state` varchar(255) DEFAULT NULL,
  `workflow_user` varchar(255) DEFAULT NULL,
  `workflow_history_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`workflow_hist_id`),
  KEY (`workflow_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `application_log`
--

DROP TABLE IF EXISTS `application_log`;
CREATE TABLE IF NOT EXISTS `application_log` (
  `application_log_id` bigint(20) unsigned NOT NULL,
  `logtimestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `workflow_id` decimal(49,0) NOT NULL,
  `priority` int(3) DEFAULT 999,
  `category` varchar(255) NOT NULL,
  `message` longtext,
  PRIMARY KEY (`application_log_id`),
  KEY (`workflow_id`),
  KEY (`workflow_id`,`priority`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;


-- --------------------------------------------------------


--
-- Table structure for table `seq_audittrail`
--

DROP TABLE IF EXISTS `seq_audittrail`;
CREATE TABLE IF NOT EXISTS `seq_audittrail` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_certificate`
--

DROP TABLE IF EXISTS `seq_certificate`;
CREATE TABLE IF NOT EXISTS `seq_certificate` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_certificate_attributes`
--

DROP TABLE IF EXISTS `seq_certificate_attributes`;
CREATE TABLE IF NOT EXISTS `seq_certificate_attributes` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_crl`
--

DROP TABLE IF EXISTS `seq_crl`;
CREATE TABLE IF NOT EXISTS `seq_crl` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_crr`
--

DROP TABLE IF EXISTS `seq_crr`;
CREATE TABLE IF NOT EXISTS `seq_crr` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_csr`
--

DROP TABLE IF EXISTS `seq_csr`;
CREATE TABLE IF NOT EXISTS `seq_csr` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_csr_attributes`
--

DROP TABLE IF EXISTS `seq_csr_attributes`;
CREATE TABLE IF NOT EXISTS `seq_csr_attributes` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_secret`
--

DROP TABLE IF EXISTS `seq_secret`;
CREATE TABLE IF NOT EXISTS `seq_secret` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_workflow`
--

DROP TABLE IF EXISTS `seq_workflow`;
CREATE TABLE IF NOT EXISTS `seq_workflow` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_workflow_history`
--

DROP TABLE IF EXISTS `seq_workflow_history`;
CREATE TABLE IF NOT EXISTS `seq_workflow_history` (
  `seq_number` bigint(20) NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Table structure for table `seq_application_log`
--

DROP TABLE IF EXISTS `seq_application_log`;
CREATE TABLE IF NOT EXISTS `seq_application_log` (
  `seq_number` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `dummy` int(11) DEFAULT NULL,
  PRIMARY KEY (`seq_number`)
) ENGINE=InnoDB  DEFAULT CHARSET=utf8;



/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;

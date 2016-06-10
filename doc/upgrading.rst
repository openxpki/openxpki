
Upgrading OpenXPKI
==================

We try hard to build releases that do not break old installations but 
sometimes we are forced to make changes that require manual adjustment
of existing config or even the database schema. 

This page provides a summary of recommended and mandatory changes.
Recommended items should be done but the installation will continue
to work. Mandatory items MUST be done, as otherwise the system will 
not behave correctly or even wont start.

For a quick overview of config changes, you should always check the
config repository at https://github.com/openxpki/openxpki-config.



Release v1.10
-------------

Please update your database schema::

  DROP TABLE IF EXISTS `seq_application_log`;
  CREATE TABLE IF NOT EXISTS `seq_application_log` (
    `seq_number` bigint(20) UNSIGNED NOT NULL AUTO_INCREMENT,
    `dummy` int(11) DEFAULT NULL,
    PRIMARY KEY (`seq_number`)
  ) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

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

Append "DBI" for the application logger in /etc/openxpki/log.conf::

   log4perl.category.openxpki.application = INFO, Logfile, DBI






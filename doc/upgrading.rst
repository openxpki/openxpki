
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


Release v1.18
-------------

Logging
#######

We removed the internal, hardcoded pattern formater for the log lines
and replaced it with native Log4perl patterns using Log4perl MDC variables
to give you more control on what and where to write to. If you do not
adjust your configs, you will still get your logs but information on
packages, etc which was hardcoded before is now gone. Check the new
sample log.conf for the new format and logging options.

Also note that the timestamps used in the application_log and audittrail
table are now written as epoch with microseconds as decimal part.

Sessions
########

There is a new session handler to get rid of filesystem sessions. The
frontend can write back the session information to the backend while
the backend can use the database to store the session data. The provided
example configuration uses those new handlers as defaults but the code
still uses the old file based sessions if you dont explicitly set the
new ones. Note that you must create the sessions table yourself when
upgrading::

    CREATE TABLE IF NOT EXISTS `session` (
      `session_id` varchar(255) NOT NULL,
      `data` longtext,
      `created` int(10) unsigned NOT NULL,
      `modified` int(10) unsigned NOT NULL,
      `ip_address` varchar(45) DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;

    ALTER TABLE `session`
     ADD PRIMARY KEY (`session_id`), ADD INDEX(`modified`);

If you use backend sessions, please also set the "cookey" secret phrase
to encrypt the session cookies in the webui config. Otherwise a person
with access to the server logs can very easily hijack running sessions!


Release v1.13
-------------

The default config now uses /var/log/openxpki/ as log directory. It is no
problem to leave your log files where there are but you need to fix the
permissions on the frontend logs after running the update::

    cd /var/openxpki/; chown www-data webui.log scep.log soap.log rpc.log

We will fix this in the debian update with the next release.

Release v1.11
-------------

We put access to workflow log/history/context under access control. If
you want your users/operators to have access to those items, you MUST add
the new acl items to your workflow definitions::

  acl:
    RA Operator:
      creator: any
      fail: 1
      resume: 1
      wakeup: 1
      history: 1
      techlog: 1
      context: 1

If you are using the SOAP revocation interface or want to use the new RPC
revocation interface, you MUST add a new field to the inital action.

Add the file config.d/realm/ca-one/workflow/global/field/interface.yaml to
your config tree.
In config.d/realm/ca-one/workflow/def/certificate_revocation_request_v2.yaml
add the field "interface" to the list of "input" fields of "create_crr".


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
    `logtimestamp` bigint(20) unsigned DEFAULT NULL,
    `workflow_id` decimal(49,0) NOT NULL,
    `priority` int(11) DEFAULT 999,
    `category` varchar(255) NOT NULL,
    `message` longtext,
    PRIMARY KEY (`application_log_id`),
    KEY (`workflow_id`),
    KEY (`workflow_id`,`priority`)
  ) ENGINE=InnoDB  DEFAULT CHARSET=utf8;

Append "DBI" for the application logger in /etc/openxpki/log.conf::

   log4perl.category.openxpki.application = INFO, Logfile, DBI






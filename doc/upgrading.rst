
Upgrading OpenXPKI
==================

We try hard to build releases that do not break old installations but
sometimes we are forced to make changes that require manual adjustment
of existing config or even the database schema.

This page provides a summary of recommended and mandatory changes.
Recommended items should be done but the installation will continue
to work. Mandatory items MUST be done, as otherwise the system will
not behave correctly or even will not start.

For a quick overview of config changes, you should always check the
config repository at https://github.com/openxpki/openxpki-config.

Release v3.32
--------------

**Important: a configuration update is required when upgrading to v3.32**

This release has several breaking changes you must address when upgrading:

* New socket and permission layout
* Mandatory version identifiers in config and database
* Updates to YAML config due to new YAML parser
* Changed logfile location for frontend logs
* Realm URLs must be unique

This release also introduces a new technical layer for the web frontend
which comes with a new configuration layout and is the default when you
install the system from scratch. We recommend to migrate you existing
configuration to the new system. The old layer is still supported but
you need to make some minor adjustments to your configuration to run it.

Socket and permissions
######################

The frontend client now runs as a dedicated process and the communication
sockets are now inside `/run`, permissions and process logic is now handled
mostly by systemd. The socket of the backend client is now at
`/run/openxpkid/openxpkid.sock`, the package installer creates a symlink
if the old location exists but it is easier to just remove the socket
location from all config files as the new release assumes the new location
as default in any place.

The owner and group permissions have been changed for the new layout, if you
want to run the old frontend, you need to adjust the permission so the
webserver can talk to the backend!

Mandatory Versioning
####################

Add the depend node in the file `system/version.yaml`::

    depend:
      core: 3.32
      config: 2

You also need to add a version identifier to the SQL tables, check if your
schema is up to date - instructions to add the schema are in the SQL files.

YAML Update
###########

OpenXPKI uses the pattern `+YYMMDD...` to specify relative dates in several
places. In the old configuration those are given as plain strings, e.g.

    validity:
        notafter: +01

The new YAML parser interpretes this as number and strips the leading
zeros which leads to unexpected behaviour and malformat errors. Please
review your configuration and add quotes around:

    validity:
        notafter: "+01"

Logfiles
########

The default logger configuration for the webfrontend / client parts is now
`/var/log/openxpki-ui`. As the installer creates this with permissions set
for the new layout you need to change this to run the old frontend.
Unability to write to this folder will crash the frontend immediately.

Realm URLs
##########

Due to changes in the URL handling it is no longer possible to use
`/webui/index/` to log into the PKI with the old frontend code when only
one realm is configured. If you do not want to upgrade, use the realm map
and assign a dedicated name to your realm, e.g. `/webui/democa/`.


Release v3.12
--------------

**Important: a configuration update is required when upgrading to v3.12**

Major rework of the authentication layer - the handlers `External` and `ClientSSO`
that were also referenced in the default configuration (but of no real use in the
default setup) have been **removed** from the code tree. A similar functionality
is available via the new handlers `NoAuth` and `Command`. In case you have those
handlers as "leftovers" of the default configuration you should just remove them.
If you have used them, please adjust the configuration before you upgrade.


Release v3.x
------------

To upgrade from v2 or an earlier v3 installation to v3 please see the Upgrade document in the openxpki-config repository.

In case you have written your own code or used the command line tools please note that the old API was removed, and some output formats have changed! You can find the API documentation as "perldoc" the implementation classes (located in OpenXPKI::Base::API::Plugin).

Release v2.3
-------------

The config parameters for the ClientX509 authentication handler have changed. In case you left the file "handler.yaml" and "stack.yaml" in realm/democa/auth/ unchanged you *MUST* remove or change the block for the "ClientX509" handler as the new/fixed handler will not work with the old config and OpenXPKI will not start at all!

Release v2.x
-------------

Upgrading from v1.x to v2.x requires some manual changes!

You MUST upgrade your database schema::

    ALTER TABLE `certificate`
      ADD `revocation_time` int(10) unsigned DEFAULT NULL,
      ADD `invalidity_time` int(10) unsigned DEFAULT NULL,
      ADD `reason_code` varchar(50) DEFAULT NULL,
      ADD `hold_instruction_code` varchar(50) DEFAULT NULL;

    UPDATE `crr` crr LEFT JOIN certificate crt USING (identifier)
    SET crt.reason_code = crr.reason_code,
        crt.revocation_time = crr.revocation_time,
        crt.invalidity_time = crr.invalidity_time,
        crt.hold_instruction_code = crr.hold_code;

    ALTER TABLE `workflow_history`
    ADD`workflow_node` varchar(64) DEFAULT NULL;

    ALTER TABLE `crl`
    ADD `crl_number` decimal(49,0) DEFAULT NULL,
    ADD `items` int(10) DEFAULT 0,
    ADD KEY `crl_number` (`issuer_identifier`,`crl_number`);


You SHOULD copy over the new default workflows, the old default workflows
SHOULD continue working but some of the workflow classes have changed, so in
case you made extensions please check the configuration for deltas!

In case you use SCEP please note that the definition of the workflow to use
has moved from the "outer" wrapper configuration to the "inner" configuration
file inside the realm. You should also switch from the old workflow type
"enrollment" to the new "certificate_enroll" which has basically the same
functionality but a lot better error handling and extensions. Note that the
format of the workflow configuration file was also changed! Check the provided
samples for details.

Release v1.19
-------------

**Warning** We changed the internal serialization format which also
affects the workflow persistence layer. Workflows or data pool structures
that are created or modified will use the new serialization format which
cannot be read by older versions! So be aware that a downgrade or parallel
operation of new and old release versions is not possible!


Release v1.18
-------------

Logging
#######

We removed the internal, hardcoded pattern formatter for the log lines
and replaced it with native Log4perl patterns using Log4perl MDC variables
to give you more control on what and where to write to. If you do not
adjust your configs, you will still get your logs but information on
packages, etc. which was hardcoded before is now gone. Check the new
sample log.conf for the new format and logging options.

Also note that the timestamps used in the application_log and audittrail
table are now written as epoch with microseconds as decimal part.

Sessions
########

There is a new session handler to get rid of filesystem sessions. The
frontend can write back the session information to the backend while
the backend can use the database to store the session data. The provided
example configuration uses those new handlers as defaults, but the code
still uses the old file based sessions if you do not explicitly set the
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
to encrypt the session cookies in the webui config. Otherwise, a person
with access to the server logs can very easily hijack running sessions!


Release v1.13
-------------

The default config now uses /var/log/openxpki/ as log directory. It is no
problem to leave your log files where there are but you need to fix the
permissions on the frontend logs after running the update::

    cd /var/openxpki/; chown www-data webui.log scep.log soap.log rpc.log

We will fix this in the Debian update with the next release.

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

Add the file config.d/realm/democa/workflow/global/field/interface.yaml to
your config tree.
In config.d/realm/democa/workflow/def/certificate_revocation_request_v2.yaml
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






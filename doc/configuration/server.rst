Global
======

This document give a brief overview over the system configuration items. You find those settings in the files in the ``<configfir>/config.d/system`` directory.

Database
--------
Configure the settings for the database layer. You need at least a configuration for the *main* database. It is possible to provide a seperate database for logging purposes, just copy the complete block from ``system.database.main`` to ``system.database.logging`` and adjust as required. If you don't configure a logging database, the main database is used.

The general configuration block looks like::

    main:
        type: supported driver name
        name: name of the database
        host: host
        port: port
        user: database user
        passwd: database credential
        namespace: namespace (to be used with oracle)
        environment:
            db_driver_env_key: value
        driver:
            LongReadLen: 10000000

OpenXPKI supports MariaDB (MySQL), PostgreSQL and Oracle.
The *namespace* parameter is used only by the Oracle driver.
Options given to ``driver`` are passed to DBI as extra parameters.

Check perldoc OpenXPKI::Server::Database::Driver::<type> for more info on the parameters.

The recommended driver is ``MariaDB2`` which uses the perl MariaDB driver module while
``MariaDB`` internally uses the old ``mysql`` driver of perl. Depending on the OS and perl
version used this might just be an alias but we have also seen very strange issues here.
*Note:* It looks like the DBD::MariaDB module shipped with bookworm has an issue with reference
counters leading to very messy log output and **might** also have implications on security or
system stability - we therefore recommend to stick with the ``MariaDB`` module in combination
with the old ``libdbd-mysql-perl`` driver.


System
-----------------------
Settings about filesystem, daemon and services to start. Located at ``system.server``

**os related stuff**

i18n locale settings::

    i18n:
        locale_directory: path to the gettext locales on your system
        default_language: supported locale (e.g. en_US.utf8)

Location of the locale files and the default language used. If you set another language than ``C``, make sure you have the correct po-files installed, otherwise OpenXPKI won't even start! This usually only affects logging and system messages as most of the client related output uses the locale settings from the client session. We recommend using *C* as default.

**daemon settings**

Those settings determine the properties of the OpenXPKI daemon `openxpkid`.::

    name:          label for your process list, useful if you are running multiple servers.
    user:          Unix user to run as (numeric or name)
    group:         Group to run as (numeric or name)

    socket_file:   Location of the communication socket.
    pid_file:      Location of the pid file.
    environment:
        key: value

    log4perl:      path to your Log4perl configuration file (the primary system logger).
    stderr:        File to redirect stderr to after dettaching from console.
    tmpdir:        Location for temporary files, writable by the daemon.

    session:
        directory: Directory to store the session information.
        lifetime:  Lifetime of the sessions on the server side.

The socket, pidfile and stderr are created during startup while running as root. The directory must exist, be writeable by root and accessible by the user the daemon runs as. The *tmpdir* must be writable by the daemon user, it can be a ramfs but can grow large in high volume environments.

**system internals**

::

    transport:
        Simple: 1

The transport setting is reserved for future use, leave it untouched.

::

    service:
        Default:
            enabled: 1
            timeout: 120

The *service* block lists all services to be enabled, the key is the name of the service, the *enabled* key is supported by all services, for all other parameters consult the concrete service documentation (perldoc OpenXPKI::Service::<ServiceName>).

**multi-node support** ::

    shift: 8
    node:
        id: 0

    data_exchange:

TODO - this is not used yet

Server Type (Fork vs. PreFork)
------------------------------

The default is ``Fork`` which create a new child on every incoming
connection, handles the current request and exits. The webui resuses the
backend connection as long as the CGI wrapper is running but most of the
other clients don't and there require a new fork on every request.

To reuse existing childs you can set the server type to prefork which
forkes of child process on server startup and reuses them for multiple
connections. In server.yaml uncomment this block::

    type: PreFork
    prefork:
      min_servers: 5
      min_spare_servers: 5
      max_servers: 25
      max_spare_servers: 10

The option is optional, if not provided the defaults of the Net::Server
module are used.

Watchdog
--------

The openxpkid daemon forks a watchdog process to take care of background processes.
It is initialised with default settings, but you can provide your own values by setting them at ``system.watchdog``. ::

    # How to deal with exceptions
    max_exception_threshhold: 10
    interval_sleep_exception: 60
    max_tries_hanging_workflows:  3

    # Control the wait intervals
    interval_wait_initial: 60
    interval_loop_idle: 5
    interval_loop_run: 1

    # You should not change this unless you know what you are doing
    max_instance_count: 1
    disabled: 0

Please see perldoc OpenXPKI::Server::Watchdog for details.

Crypto layer (global)
---------------------
Define several parameters for the basic crypto tools.

**configuration of the default tokens**

::

    token:
        default:
            backend: OpenXPKI::Crypto::Backend::OpenSSL
            api:     OpenXPKI::Crypto::Backend::API
            engine:  OpenSSL
            key_store: OPENXPKI

            # OpenSSL binary location
            shell: /usr/bin/openssl

            # OpenSSL binary call gets wrapped with this command
            wrapper: ''

            # random file to use for OpenSSL
            randfile: /var/openxpki/rand

        javaks:
            backend: OpenXPKI::Crypto::Tool::CreateJavaKeystore
            api: OpenXPKI::Crypto::Tool::CreateJavaKeystore::API

If you have non-standard file locations, you might want to change the OpenSSL relevant settings here, the *wrapper* allows you to provide the name of a wrapper command which is commonly necessary if you use hardware security modules or other special OpenSSL eninges for your crypto operations. See the section about using HSMs for more details.

Developer note: See OpenXPKI::Crypto::TokenManager::get_system_token


PKI Realms
----------
The detailed settings of each realm are given in the specific realm configuration. To use a realm you need to specify and enable it at ``system.realms``. ::

    democa:
        label: This is just a verbose label for your CA

You should use only 7bit word characters and no spaces as name for the realm.



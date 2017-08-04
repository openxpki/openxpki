Subsystems providing External APIs
===================================

OpenXPKI comes with a set of subsystems that can be used to search
for certificates and handle workflows using different established or
custom APIs.

The most common one ist the SCEP interface that supports enrollment
of certificates using the "Simple Certificate Enrollment Protocol" which
was developed by Cisco and is widely used in hardware devices.

A generic SOAP and RPC wrapper is also available which can be used to
implement arbitrary workflows. Some samples are already included in the
default config.

If you want connect your Microsoft Windows environment to OpenXPKI, have
a look on the "Certificate Enrollment Proxy" (https://www.secardeo.de/produkte/certep/).
This commercial product is a snap-in that routes certificate requests
from a Microsoft CA to OpenXPKI, enabling approval workflows and certificate
lifecycle management for Windows environments.

.. _subsystem-wrapper:

Wrapper Configuration
-----------------------

All wrappers are implemented as a fast-cgi script with the default
webserver handling the HTTP layer, talking to the OpenXPKI daemon using
the existings socket. The basic configuration pattern is the same for
all subsystems, just replace the ``rpc`` used in the given samples with
the name of the wrapper.

Each wrapper has a directory of the same name in the openxpki main config
folder (e.g. /etc/openxpki/rpc) holding the global default and the logger
config at least. Currently, only the Config::Std format is supported for
those files!

Global Default Config
^^^^^^^^^^^^^^^^^^^^^

The name of the global config file must be ``default.conf`` and consists
of a [global] section holding information on logger and socket::

    [global]
    log_config = /etc/openxpki/rpc/log.conf
    log_facility = client.rpc
    socket = /var/openxpki/openxpki.socket

    [auth]
    stack = _System

**log_config** must point to the Log4perl configuration file that should be
used by this wrapper. If the file is not found or the opion is missing, the
default logger writing to STDERR is used.

**log_facility** The facility name to log with, this is useful if you want to
log to the same file from multiple different systems.

**socket** Full path of the OpenXPKI socket file

**stack** Name of the authentication stack, default is to connect as
Anonymous, all additional attributes are passed unaltered to the
authentication layer. See OpenXPKI::Client::Simple.

Config Path Expansion
^^^^^^^^^^^^^^^^^^^^^^

If you run the cgi wrapper scripts using the provided Alias rules, you can
have multiple named configurations. Call the wrapper using an alias
path like ``http://host/rpc/vpnclient`` to load the config information from
``/etc/openxpki/rpc/vpnclient.conf``.

If no file is found, the default config is loaded from
/etc/openxpki/scep/default.conf. The wrapper uses SCRIPT_URL or REQUEST_URI
from the apache environment to extract the requests path, this should work
in most environments with mod_rewrite, symlinks or alias definitions. If you
use another webserver then apache, you might need to adjust the autodetection
rules to fit your needs.

**Note** he wrappers run as persistent scripts and are initialized before the
alias path is known. The socket and logger config is therefore *always* read
from the default.conf!

custom base directory
^^^^^^^^^^^^^^^^^^^^^^
The value of ``OPENXPKI_CLIENT_CONF_DIR`` overwrites the default of the top
level configuration folder ``/etc/openxpki``. If set, the service is config is
loaded from  ``OPENXPKI_CLIENT_CONF_DIR/<servicename>``.

custom service directory
^^^^^^^^^^^^^^^^^^^^^^^^

Set ``OPENXPKI_RPC_CLIENT_CONF_DIR`` to a directory path. The autodetection
will now use this path to find either the special or the default file. Note
that there is no fallback to the default location!

fixed file
^^^^^^^^^^

Set ``OPENXPKI_RPC_CLIENT_CONF_FILE`` to an absolute file path. On apache,
this can be combined with location to set a config for a special script::

   <Location /cgi-bin/rpc/mailgateway>
      SetEnv OPENXPKI_SCEP_CLIENT_CONF_FILE /home/mailadm/rpc.conf
   </Location>

Log4perl Config
---------------

The default Log4perl config shipped with the sample config file looks like::

    log4perl.category.client.rpc = INFO, Logfile

    log4perl.appender.Logfile  = Log::Log4perl::Appender::File
    log4perl.appender.Logfile.filename = /var/log/openxpki/rpc.log
    log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Logfile.layout.ConversionPattern = %d %p:%P %m%n
    log4perl.appender.Logfile.syswrite  = 1

**Note**: The wrappers run in the context and with permissions of the webserver!
You need to make sure that the directory or preexisting files have appropriate
permission to be written/created by this user/group!


Webserver Config
-----------------

Config Path Expansion
^^^^^^^^^^^^^^^^^^^^^

The most convenient was to enable the path expansion is to use the ``Alias``
directive::

    # Same for RPC
    ScriptAlias /rpc  /usr/lib/cgi-bin/rpc.fcgi

    <Directory "/usr/lib/cgi-bin/">
        AllowOverride None
        Options +ExecCGI
        Order allow,deny
        Allow from all
        # Remove this line if you are using apache 2.2
        Require all granted
    </Directory>

.. _subsystem-wrapper-tlsauth:

TLS Client Authentication
^^^^^^^^^^^^^^^^^^^^^^^^^
All wrappers except SCEP support authentication using TLS client certificates.
The recommended way is to let apache do the TLS handshake but pass the full
client certificate to OpenXPKI::

    SSLVerifyClient optional
    SSLVerifyDepth  3
    SSLCACertificateFile /etc/apache2/ssl/root.pem

    SSLOptions +FakeBasicAuth +ExportCertData +StrictRequire
    <Directory /usr/lib/cgi-bin>
            SSLOptions +StdEnvVars
    </Directory>

This makes the properties and the full certificate as PEM available in the
SSL_* environment variables where there are picked up as needed and injected
into the workflow engine by the wrappers.

Endpoint Configuration
----------------------

Most of the workflows used with the external APIs use a common pattern
to load endpoint specific settings. The interface type together with the
servername is used as base path for config lookups. Note that the
servername is given explicit in the wrapper config and can be different
from the exposed script name.

A sample RPC endpoint configuration might look like::

    [RequestCertificate]
    workflow = certificate_enroll
    param = pkcs10, comment
    output = cert_identifier, error_code
    env = signer_cert
    servername = vpnclient

The base path for config lookups is now, inside the realm config
``rpc.vpnclient``.

TLS Client Authorization
^^^^^^^^^^^^^^^^^^^^^^^^

A widely used example is the check if a client is authorized to run the
workflow based on the provided TLS certificate. Most of the workflows use the
OpenXPKI::Server::Workflow::Activity::Tools::EvaluateSignerTrust
action class for this which grabs the ruleset from
``interface.servername.authorized_signer``, in our example
``rpc.vpnclient.authorized_signer``::

  authorized_signer:
    rule1:
      subject: CN=.+:pkiclient,.*

    rule2:
      profile: I18N_OPENXPKI_PROFILE_VPN_CLIENT
      realm: vpn-ca

    rule3:
      identifier: AhElV5GzgFhKalmF_yQq-b1TnWg


The provided certificate is matched against each rule, the check returns true
if all conditions of one rule are met. The realm is always set to the current
realm if not given explicit. The subject is matched as case-insensitive regex
all other attributes are matched as equal strings.


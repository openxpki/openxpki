Subsystems providing External APIs
===================================

OpenXPKI comes with a set of subsystems that can be used to search
for certificates and handle workflows using different established or
custom APIs.

The most common one is the SCEP interface that supports enrollment
of certificates using the "Simple Certificate Enrollment Protocol" which
was developed by Cisco and is widely used in hardware devices.

A generic RPC wrapper is also available which can be used to
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

*Note* With v3.32 the interface layer has been reimplemented using the
Mojolicious application server, the old FCGI based scripts are still
part of the package but are no longer actively supported.

The application server reads its configuration from ``/etc/openxpki/client.d``,
the configuration for service layers is in ```service/<service name>``. To
provide a service you must create a so called *endpoint* which links an URL
path to a configuration.

The pattern is idiomatic, to e.g. provide an SCEP endpoint to enroll your
printers create the file ``client.d/service/scep/printers.yaml`` and point
your devices to ``http://pki.company.com/scep/printers``.

General configuration is equal to all services:

Global Configuration
^^^^^^^^^^^^^^^^^^^^

The global node is mandatory to link the endpoint to a realm::

  global:
      realm: democa

Web requests also need to authenticate themselves against the backen,
the anonymouse ``_System`` stack is the default and can also be omited::

  auth:
      stack: _System

Logging goes to predefined files with loglevel *INFO*, you can change
the loglevel per endpoint::

  logger:
    # Log level: overrides system.logger.level
    #   "DEBUG" MIGHT disclose sensitive user input data.
    #   "TRACE" WILL dump unfiltered communication.
    level: INFO


Webserver Config
-----------------

Please have a look at the provided apache example configuration to
understand how the mapping works.

.. _subsystem-wrapper-tlsauth:

TLS Client Authentication
^^^^^^^^^^^^^^^^^^^^^^^^^
All wrappers except SCEP support authentication using TLS client certificates.
The recommended way is to let apache do the TLS handshake but pass the full
client certificate to OpenXPKI::

    SSLCACertificatePath /etc/openxpki/tls/chain/
    SSLVerifyClient optional_no_ca
    SSLVerifyDepth 3
    SSLOptions +StdEnvVars +ExportCertData

This makes the properties and the full certificate as PEM available in the
SSL_* environment variables where there are picked up as needed and injected
into the workflow engine by the wrappers.


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
      profile: vpn_client
      realm: vpn-ca

    rule3:
      identifier: AhElV5GzgFhKalmF_yQq-b1TnWg


The provided certificate is matched against each rule, the check returns true
if all conditions of one rule are met. The realm is always set to the current
realm if not given explicit. The subject is matched as case-insensitive regex
all other attributes are matched as equal strings.


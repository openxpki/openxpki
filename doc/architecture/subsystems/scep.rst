SCEP Server
===========

The scep functionality is included as a special service with the core distribution.
For historic reasons, the name of the SCEP service is "SCEPv2" which needs to
be enabled in the global system configuration (``system.server.service``).

The communication with your scep clients requires the deployment of a cgi wrapper
script with your webserver. The script will just parse the HTTP related parts and
pass the data to the openxpki daemon and vice versa.

Wrapper Configuration
---------------------

The default wrapper looks for its config file at ``/etc/openxpki/scepv2.conf``.
The config uses plain ini format, a default is deployed by the package::

    [global]
    socket=/var/openxpki/openxpki.socket
    realm=ca-one
    iprange=0.0.0.0/0
    profile=I18N_OPENXPKI_PROFILE_TLS_SERVER
    servername=scep-server-1
    encryption_algorithm=3DES

This config matches the settings from the default core config, most settings
should be explanatory by themselves. The file is only used by the cgi wrapper
and it is an accepted solution to create multiple copies of the wrapper with
fixed parameters.




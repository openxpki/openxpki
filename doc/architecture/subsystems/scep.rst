SCEP Server
===========

The scep functionality is included as a special service with the core distribution.
The scep service needs to be enabled in the global system configuration 
(``system.server.service``).

The communication with your scep clients requires the deployment of a cgi wrapper
script with your webserver. The script will just parse the HTTP related parts and
pass the data to the openxpki daemon and vice versa.

Wrapper Configuration
---------------------

The default wrapper looks for its config file at ``/etc/openxpki/scep/default.conf``.
The config uses plain ini format, a default is deployed by the package::

    [global]
    socket=/var/openxpki/openxpki.socket
    realm=ca-one
    iprange=0.0.0.0/0
    profile=I18N_OPENXPKI_PROFILE_TLS_SERVER
    servername=scep-server-1
    encryption_algorithm=3DES      

Parameters
^^^^^^^^^^

**socket**

Location of the OpenXPKI socket file, the webserver needs rw access.

**realm**

The realm of the ca to be used.

**iprange**

Implements a simple ip based access control, the clients ip adress is checked
to be included in the given network. Only a single network definition is
supported, the default of 0.0.0.0/0 allows all ips to connect.

**profile**

The profile of the certificate to be requested, note that depending on the
backing workflow this might be ignored or overridden by other paramters.

**servername**

Path to the server side config of this scep service. Equal to the key from
the config section in the scep.yaml file.

**encryption**

Encrpytion to use, supported values are I<DES> and I<3DES>.

Multiple Configs
^^^^^^^^^^^^^^^^^

The default location for config files is /etc/openxpki/scep, the script
will use the filename of the called script (from ENV{SCRIPT_NAME)) and looks
for /etc/openxpki/scep/<filename>.conf. If no file is found, the default
config is loaded from /etc/openxpki/scep/default.conf.
Note: The scriptname value respects symlinks, so you can use a single scep
handler script and create symlinks on it.

**custom base directory**

Set *OPENXPKI_SCEP_CLIENT_CONF_DIR* to a directory path. The autodetection
will now use this path to find either the special or the default file. Note
that there is no fallback to the default location!

**fixed file**

Set *OPENXPKI_SCEP_CLIENT_CONF_FILE* to an absolute file path. On apache, 
this can be combined with location to set a config for a special script::

   <Location /cgi-bin/scep/mailgateway>
      SetEnv OPENXPKI_SCEP_CLIENT_CONF_FILE /home/mailadm/scep.conf
   </Location>

   
   
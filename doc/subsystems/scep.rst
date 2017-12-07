SCEP Server
===========

The scep functionality is included as a special service with the core
distribution and enabled by default. You can turn it off in the global
system configuration (``system.server.service``).

The communication with your scep clients requires the deployment of a cgi wrapper
script with your webserver. The script will parse the HTTP related parts and
pass the data to the openxpki daemon and vice versa.

Wrapper Configuration
---------------------

The default wrapper looks for its config file at ``/etc/openxpki/scep/default.conf``.
The config uses plain ini format, a default is deployed by the package::

    [global]
    log_config = /etc/openxpki/scep/log.conf
    log_facility = client.scep
    socket=/var/openxpki/openxpki.socket
    realm=ca-one

    iprange=0.0.0.0/0
    profile=I18N_OPENXPKI_PROFILE_TLS_SERVER
    servername=scep-server-1
    encryption_algorithm=3DES

Parameters
^^^^^^^^^^

**log_config/log_facility/socket**

Described in the common wrapper documentation (:ref:`subsystem-wrapper`).

**realm**

The realm of the ca to be used.

**iprange**

Implements a simple ip based access control, the clients ip adress is checked
to be included in the given network. Only a single network definition is
supported, the default of 0.0.0.0/0 allows all ips to connect.

**profile**

The default profile of the certificate to be requested, note that depending on
the backing workflow this might be ignored or overridden by other paramters.

**servername**

Path to the server side config of this scep service. Equal to the key from
the config section in the scep.yaml file.

**encryption**

Encrpytion to use, supported values are I<DES> and I<3DES>.


Config Path Expansion
^^^^^^^^^^^^^^^^^^^^^

Is supported by the SCEP wrapper, the service name is ``scep``. See the
common wrapper documentation (:ref:`subsystem-wrapper`) for details.

Support for Root Rollover using GetNextCA
-----------------------------------------

One of the most powerful features of OpenXPKI is the support for a seamless
rollover of CA generations. To distribute a new root certificate in your
infrastructure, SCEP provides the "GetNextCA" command which sends the new
root certificate signed by the current SCEP service.

To configure the certificate delivered by GetNextCa, you must add a
certificate alias into the CA realm with a future notbefore date.

If not done already, import your new root certificate into the database::

    openxpkiadm certificate import --file my-new-rootca.pem

Now create a new alias in the ``root`` group to point to this certificate.
Replace the XXXX with the identifier shown by the import command::

    openxpki alias --realm ca-one --token root \
       --identifier XXXX   --notbefore "2020-01-01 00:00:00"

The actual value of the notbefore date is irrelevant, it just must be in
the future.

Check the result by listing your aliases::

    openxpki alias --realm ca-one

    === root ca ===
    current root ca:
      Alias     : root-1
      Identifier: 9p_FxU-wdTaciZD5lcOIiP-CLxk
      NotBefore : 2015-10-02 09:26:28
      NotAfter  : 2020-10-01 09:26:28

    upcoming root ca:
      Alias     : root-2
      Identifier: Als6THNt9jedxlF5AD0P5a4bhjY
      NotBefore : 2020-10-01 09:26:25 (2006-11-03 07:00:58)
      NotAfter  : 2030-12-31 23:59:00


Caveats
-------

The scep standard is not exact about the use of HTTP/1.1 features.
We saw a lot of clients which where sending plain HTTP/1.0 requests which
is not compatible with name based virtual hosting!

Please do **NOT** use SCEP over HTTPS, SCEP transport is protected on the
application layer by default.


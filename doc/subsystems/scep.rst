SCEP Server
===========

The communication with your scep clients requires the deployment of a cgi wrapper
script with your webserver. The script will parse the HTTP related parts and
pass the data to the openxpki daemon and vice versa.

Decommission and Upgrade Notice
--------------------------------

With v3.26 the old SCEP wrappers based on a dedicated service layer are
no longer supported. You need to remove the service related items from
``system.server.service``, ``system.crypto.tokenapi`` and point the
``/scep`` alias rules in the apache wrapper to the ``scepv3.fcgi`` script.
You also need to update the wrapper configurations in the
``/etc/openxpki/scep`` folder and the workflow configurations in the
realms.


Wrapper Configuration
---------------------

The default wrapper looks for its config file at ``/etc/openxpki/scep/default.conf``.
The config uses plain ini format, a default is deployed by the package::

  [global]
  socket=/var/openxpki/openxpki.socket
  realm=democa
  servername=generic

  [logger]
  # A loglevel of DEBUG MIGHT disclose sensitive user input data
  # A loglevel of TRACE WILL dump any communication unfiltered
  log_level = INFO

  [auth]
  stack=_System

  # OpenXPKI supports mapping additional URL Parameters to the workflow
  # Those must be whitelisted here for security reasons
  [PKIOperation]
  param = signature


Config Path Expansion
^^^^^^^^^^^^^^^^^^^^^

Is supported by the SCEP wrapper, the service name is ``scep``. See the
common wrapper documentation (:ref:`subsystem-wrapper`) for details.

Caveats
-------

The scep standard is not exact about the use of HTTP/1.1 features.
We saw a lot of clients which where sending plain HTTP/1.0 requests which
is not compatible with name based virtual hosting!

Please do **NOT** use SCEP over HTTPS, SCEP transport is protected on the
application layer by default.


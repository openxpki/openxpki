SCEP Server
===========

In general the SCEP server does not need a lot of configuration, the
example repository provides an endpoint named ``generic`` with a
minimal configuration.

To create additional endpoints just create a copy with the expected
endpoint name and do not forget to add a matching backend configuration
inside the realm.

Caveats
-------

The scep standard is not exact about the use of HTTP/1.1 features.
We saw a lot of clients which where sending plain HTTP/1.0 requests which
is not compatible with name based virtual hosting!

Please do **NOT** use SCEP over HTTPS, SCEP transport is protected on the
application layer by default.


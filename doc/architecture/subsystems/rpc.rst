RPC Server API
==============

The RPC Service provides a simple HTTP-Based API to the OpenXPKI backend.
The builtin REST Server provides methods to request, renew and revoke 
certificates. The service is implemented using a cgi-wrapper script with 
a rewrite module (e.g. mod_rewrite).

Currently, the only method implemented is for revoking certificates.

This document describes

* Server-Side Configuration
* Exposed RPC Methods

Server-Side Configuration
=========================

Wrapper Configuration
---------------------

The default wrapper looks for its config file at ``/etc/openxpki/rpc/default.conf``.
The config uses plain ini format, a default is deployed by the package::

  [global]
  log_config = /etc/openxpki/rpc/log.conf
  log_facility = client.rpc
  socket = /var/openxpki/openxpki.socket

  [auth]
  stack = _System
  pki_realm = ca-one

Endpoint Configuration
----------------------

Based on the given servername, a rules file is loaded for the server.
You can define the rules for the signer authorization here::

  authorized_signer:
      rule1:
          subject: CN=.+:soapclient,.*
      rule2:    
          subject: CN=.+:pkiclient,.*

Authentication
--------------

The default configuration exposes the API without enforcing authentication,
but evaluates the apache environment variables for traces of HTTP Basic 
Authentication (HTTP_USER) or TLS Client Authentication (SSL_CLIENT_S_DN).

Ressource updates are always turned into OpenXPKI workflows, with the found
authentication information passed to them.

@todo: Explain how auth works for RPC in new chapter


Exposed Methods
===============

The default is to expect/return JSON formatted data, but some methods will
accept/return other formats, too.

Parameters are expected in the query string or in the body of the
HTTP POST operation (application/x-www-form-urlencoded). At minimum,
the parameter "method" must be provided. The name of the method used
must match a section in the configuration file, which must at least 
contain the name of a workflow.

Revoke Certificate by Certificate Identifier
--------------------------------------------

The endpoint is configured in ``/etc/openxpki/rpc/default.conf`` with
the following:

    [RevokeCertificateByIdentifier]
    workflow = certificate_revocation_request_v2
    servername = signed-revoke

See ``core/server/cgi-bin/rpc.cgi`` for mapping additional parameters,
if needed.

Certificates are revoked by specifying the certificate identifier. 

    curl \
        --data "method=RevokeCertificateByIdentifier" \
        --data "cert_identifier=3E9tpLu5qpXarcQHnD1LUNsJIpU" \
        --data "reason_code=unspecified" \
        http://demo.openxpki.org/cgi-bin/rpc.cgi

The response is in JSON format (http://www.jsonrpc.org/specification#response_object).
Except for the "id", the result is identical to the SOAP call:

    { result: { id: workflow_id, pid: process_id, state: workflow_state }}

On error, the content returned is:

    { error: { code: 1, message: "Verbose error", data: { id, pid, state } } }

The following HTTP Response Codes are (to be) supported:

* 200 OK - Request was successful

* 400 Bad Request - Returned when the RPC method or required parameters
  are missing.

* 401 Unauthorized - No or invalid authentication details were provided

* 403 Forbidden - Authentication succeeded, but the authenticated user does
  not have access to the resource

* 404 Not Found - A non-existent resource was requested

* 500 Internal Server Error - Returned when there is an error creating an
  instance of the client object or a new workflow, or the workflow terminates
  in an unexpected state.

See Also
========

See the OpenXPKI documentation for further information.
See also ``core/server/cgi-bin/rpc.cgi``.









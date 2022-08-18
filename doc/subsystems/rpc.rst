RPC Server API
##############

The RPC Service provides a simple HTTP-Based API to the OpenXPKI backend.
The builtin REST Server provides methods to request, renew and revoke
certificates. The service is implemented using a cgi-wrapper script.

Server-Side Configuration
=========================

Wrapper Configuration
---------------------

The default wrapper looks for its config file at ``/etc/openxpki/rpc/default.conf``.
The config uses plain ini format, a default is deployed by the package::

  [global]
  socket = /var/openxpki/openxpki.socket
  locale_directory: /usr/share/locale
  default_language: en_US

  [logger]
  log_level = WARN

  [auth]
  stack = _System

  [input]
  allow_raw_post = 1
  parse_depth = 5

  [output]
  use_http_status_codes=0

The global/auth/logger parameters are described in the common wrapper
documentation (:ref:`subsystem-wrapper`). Config path extension and
TLS Authentication is supported.


TLS Authentication
-------------------

In case you want to use TLS Client authentication you must tell the
webserver to pass the client certificate to the script. For apache,
put the following lines into your SSL Host section::

    <Location /rpc>
        SSLVerifyClient optional
        SSLOptions +StdEnvVars +ExportCertData
    </Location>

Note: We need the apache just to check if the client has access to the
private key of the certificate. Trust and /revocation checking is done
inside of OpenXPKI so you can also use "optional_no_ca" if you dont
want to deal with setting up the correct chains in apache.
Blocking clients on TLS level might be a good idea if your service is
exposed to "unfriendly users".

Input Handling
==============

allow_raw_post
--------------

Adds the option to post the parameters as json string as raw http body.
As we currently do NOT sanitize the parameters send there is a chnace for an
attacker to inject serialized json objects this way! So do NOT set this until
you are running in a trusted, controlled environemnt or have other security
mechanisms in place.

parse_depth
-----------

Maximum allowed recursion depth for the JSON body, the default is 5.

Parameter Handling
===================

Input parameters are expected to be passed either via query string or in
the body of the HTTP POST operation (application/x-www-form-urlencoded).

At minimum, the parameter "method" must be provided. The name of the method
used must match a section in the configuration file, which must at least
contain the name of a workflow.

If you have setup config path expansion, you can append the method as third
parameter to the URL instead::

    http://demo.openxpki.org/rpc/helpdesk/RevokeCertificateByIdentifier

The default is to return JSON formatted data, if you set the I<Accept>
header of your request to "text/plain", you will get the result as plain
text with each key/parameter pairs on a new line.

Example: Revoke Certificate by Certificate Identifier
-----------------------------------------------------

The endpoint is configured in ``/etc/openxpki/rpc/enroll.conf`` with
the following::

    [RevokeCertificate]
    workflow = certificate_revocation_request_v2
    param = cert_identifier, reason_code, comment, invalidity_time
    env = signer_cert, signer_dn, server
    output = error_code

See ``core/server/cgi-bin/rpc.cgi`` for mapping additional parameters,
if needed.

Certificates are revoked by specifying the certificate identifier::

    curl \
        --data "method=RevokeCertificateByIdentifier" \
        --data "cert_identifier=3E9tpLu5qpXarcQHnD1LUNsJIpU" \
        --data "reason_code=unspecified" \
        http://demo.openxpki.org/cgi-bin/rpc.cgi

The response is in JSON format (http://www.jsonrpc.org/specification#response_object).
Except for the "id" parameter, the result is identical to the definition of JSON RPC::

    { result: {
        id: workflow_id, pid: process_id, state: workflow_state, proc_state: proc_state
    }}

On error, the content returned is::

    { error: { code: 1, message: "Verbose error", data: { id, pid, state } } }

Verbose error might be a readable error message or a I18N... translatable tag.
If you set default_language in the wrapper configuration the I18N tags are
translated.

Response
========

By default, the HTTP Status code is always "200 ok" with a numeric error
code set in the return structure. The error codes consist of five digits,
the first three digits are derived from the HTTP status codes followed by
two digits for unambiguousness.

To let the wrapper send the error code on HTTP layer, you need to set::

  [output]
  use_http_status_codes=1

in the wrapper configuration. This will return 4xx and 5xx status codes
together with the above mentioned error structures as body.

For details on the supported error codes see the documentation of the
rpc.fcgi wrapper script.

Note: The OpenAPI Spec does not yet return the HTTP status codes.

Workflow Pickup
===============

If you have a workflow that does not return the final result immediately,
you can define a search pattern to pickup existing workflows based on
worflow_attributes::

    [RequestCertificate]
    workflow = certificate_enroll
    param = pkcs10, comment
    output = cert_identifier, error_code, transaction_id
    env = signer_cert, enroll
    pickup = transaction_id

With a properly prepared workflow, this allows you access an existing
workflow based on the transaction_id. For now it is only possible to
read existing workflows, there is no option to interact with them, yet.

Examples
========

The default.conf configuration file defines an endpoint SearchCertificate::

    [SearchCertificate]
    workflow = certificate_search
    param = common_name
    output = cert_identifier, notbefore, notafter, status

To utilize this endpoint the following curl command may be used::

    $ curl -F "method=SearchCertificate"  -F "common_name=test" http://localhost:8080/rpc

    {"result":{"id":0,"data":{"notafter":"2019-04-19T05:21:58","notbefore":"2018-10-19T05:21:58", \
    "status":"ISSUED","cert_identifier":"7Da0qfjirGl7PXlZYf9PFVqMJds"},"state":"SUCCESS","pid":915}}

The RequestCertificate endpoint (see above) may be used via::

    $ curl -F method=RequestCertificate  -F comment=test -F pkcs10="$(cat certreq.pem)" http://localhost:8080/rpc

    {"result":{"id":"5119","state":"SUCCESS","data":{"cert_identifier":"60uHCnC3Uv9wZKjcCkmSHuBwuzU"},"pid":915}}

Of course proper authentication and authorization is required for the
cerificate to be issued immediately. The required configuration parameters
are documented in the scep workflow.

.. _openapi-rpc-method:

Retrieving the OpenAPI spec
---------------------------

There is a special RPC method *openapi-spec*::

    $ curl -F "method=openapi-spec" http://localhost:8080/rpc

This will return an OpenAPI compliant specification of all possible OpenXPKI RPC method calls in JSON format.

For an OpenAPI overview please see :ref:`openapi-overview`.

See Also
========

See also ``core/server/cgi-bin/rpc.cgi``.

SOAP Server
===========

The builtin SOAP Server provides methods to revoke certificates. The 
service is implemented using a cgi-wrapper script, so there is no need
for the webserver to support SOAP, you just need to setup the wrapper 
script. For apache, just add a ScriptAlias::

   ScriptAlias /soap  /usr/lib/cgi-bin/soap.fcgi


Wrapper Configuration
---------------------

The default wrapper looks for its config file at ``/etc/openxpki/scep/default.conf``.
The config uses plain ini format, a default is deployed by the package::

  [global]
  log_config = /etc/openxpki/soap/log.conf
  log_facility = client.soap
  socket = /var/openxpki/openxpki.socket
  modules = OpenXPKI::SOAP::Revoke OpenXPKI::SOAP::Smartcard

  [auth]
  stack = _System
  pki_realm = ca-one

  [OpenXPKI::SOAP::Revoke]
  workflow = certificate_revocation_request_v2
  servername = signed-revoke

  [OpenXPKI::SOAP::Smartcard]
  workflow = sc_revoke
  servername = smartcard-revoke


Endpoint Configuration
----------------------

Based on the given servername, a rules file is loaded for the server.
You can define the rules for the signer authorization here::

  authorized_signer:
      rule1:
          subject: CN=.+:soapclient,.*
      rule2:    
          subject: CN=.+:pkiclient,.*


SOAP Methods
------------

The default interface exposes two methods. The reason code is optional
in both calls and defaults to "unspecified". Allowed values are the reason
codes as used by openssl.

RevokeCertificateByIssuerSerial
################################

This expects the full DN of the certificate issuer and the serial number
of the certificate to revoke. The serial can be either in decimal or 
hexadecimal format prefixed with '0x'::

    RevokeCertificateByIssuerSerial(
        'CN=CA ONE,OU=Test CA,DC=OpenXPKI,DC=ORG', 
        '0xdb7d5b06600bddcbecff',
        'keyCompromise'
    )

RevokeCertificateByIdentifier
#############################

Expects the OpenXPKI identifier of the certificate::

    RevokeCertificateByIdentifier(
        'TZNrDctI9RV8DT5TGvg81w7F-So',
        'keyCompromise'
    )

Both calls return a hash with id and state of the started workflow::

  {  
    'id' => '145919',
    'state' => 'PENDING',
    'error' => ''
  }

If anything goes wrong, you get a verbose error message in error::
  
  {
    'error' => 'parameter missing'
  }



Multiple Endpoints
------------------

t.b.d



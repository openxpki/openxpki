
Audit Log
=========

The audit log lists all operations that are relevant for the usage of
private key material or important steps (as approvals) that lead to a
signature using the CA key.

Categories
##########

The audit log is divided into several categories. The given items are
actions logged by the standard configuration but are not exhaustive.
The name in brackets is the name of the logger category used by the
logger.

CA Key Usage (cakey)
--------------------
* certificate issued
* crl issued

Entity Key Usage (key)
----------------------
* key generated
* key exported
* key destroyed

Certificate (entity)
----------------------
* request received
* request fully approved
* issued
* revoked

Approval (approval)
---------------------
* operator approval given via ui
* automated approval derived from backend checks

ACL (acl)
---------------------
* access to workflow
* access to api

System (system)
----------------
* start/stop of system
* import/activation of tokens
* import of certificates

Application
-----------
* Application specific logging


Parameters
##########

Each log message consists of a fixed string describing the event plus a
list of normalized parameters which are appended as key/value pairs to
the message so it is easy to search the log for certain or feed it to a
log analysis programm like logstash.

* cakey/key: subject key identifier of the used key
* certid: certificate identifier
* wfid: id of the workflow
* action: name of a workflow action or called API method
* token: alias name of the token/key, e.g. "ca-one-signer-1"
* pki_realm: name of the pki realm

Example (line breaks are for verbosity, logfile is one line)::

   certificate signed|
     cakey=28:B9:6D:51:EC:EB:6D:C9:4A:71:7C:B4:C0:67:F7:E9:C1:BD:63:7A|
     certid=FW2Hq52uTcthhyhrrvTjRub66M0|
     key=D6:14:BB:E2:90:12:F4:FF:64:B4:0F:F3:F6:3A:FD:17:02:C9:06:C8|
     pki_realm=ca-one


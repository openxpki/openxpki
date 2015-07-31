Configuration of the SCEP Workflow
====================================

Before you can use the SCEP subsystem, you need to enable the SCEP Server 
in the general configuration. This section explains the options for the 
scep enrollment workflow.


Workflow Logic
--------------

The workflow validates incoming requests against five stages. Parameters
are described in detail in the section on policy settings.

technical parameters:
    Check if key algorithm, key size and hash algorithm match the policy.
    If any of those checks fails, the request is rejected.

authentication:
    A request can either be self-signed and provide a challenge password
    or is signed by a trusted certificate (renewal or "signer on behalf"). 
    You can also disable authentication or dispatch unauthorized requests 
    to an operator for review.

subject duplicate check:
    The database is checked for valid certificates with the same subject. 
    If issuing the certificate would exceed the configured maximum count, 
    the request is dispatched to an operator wo can either reject the 
    request or take actions to meet the policy. 

eligibility:
    The basic idea is to check requests based on the subject or additonal 
    parameters against an external source to see if enrollment is possible.
    The check counts against the approval point counter, the workflow does
    not take any special action if the check fails.

approval point:
    The first four stages are usually run in one step when the request 
    hits the server. Before the certificate is issued, the request must 
    have a sufficient number of approval points. Each operator approval
    is worth one point. A passed eligibility check is also worth one.
   

Sample Configuration
--------------------

The workflow fetches all information from the configuration system at ``scep.<servername>`` where the servername is taken from the scep wrapper configuration.

Here is a complete sample configuration::
        
    key_size:
        rsaEncryption: 1020-2048
    
    hash_type: 
      - sha1
    
    authorized_signer_on_behalf:
        technicans:
            subject: CN=.*DC=SCEP Signer CA,DC=mycompany,DC=com
            profile: I18N_OPENXPKI_PROFILE_SCEP_SIGNER
        blackbox:
            identifier: JNHN5Hnje34HcltluuzooKVqxss

    challenge:
       value: SecretChallenge
    
    renewal_period: 000014   
    replace_period: 05    
    revoke_on_replace:
        reason_code: keyCompromise
        invalidity_time: +000014    

    eligible:
        initial:
           value: 0
        renewal:
           value: 1       
    
    policy:         
        allow_anon_enroll: 0
        allow_man_authen: 1
        allow_man_approv: 1        
        max_active_certs: 1
        allow_expired_signer: 0
        auto_revoke_existing_certs: 1
        approval_points: 1
    
    response:
        # The scep standard is a bit unclear if the root should be in the chain or not
        # We consider it a security risk (trust should be always set by hand) but
        # as most clients seem to expect it, we include the root by default
        # If you are sure your clients do not need the root, set this to 1
        getcacert_strip_root: 0
        
    # Mapping of names to OpenXPKI profiles to be used with the 
    # Microsoft Certificate Template Name Ext. (1.3.6.1.4.1.311.20.2)       
    profile_map:
        pc-client: I18N_OPENXPKI_PROFILE_USER_AUTHENTICATION
    
    subject_style: enroll

    token: ca-one-special-scep

    workflow_type: enrollment
    
*The renewal and replace period values are interpreted as OpenXPKI::DateTime relative date but given without sign.*

Workflow Configuration
----------------------

technical validation
++++++++++++++++++++

Configure the list of allowed key and hash algorithms.

**key_size**

A hash item list for allowed key sizes and algorithms. The name of the option must be
the key algorithm as given by openssl, the required byte count is given as a range in
bytes. There must not be any space between the dash and the numbers. Hint: Some
implementations do not set the highest bit to 1 which will result in a nominal key
size which is one bit smaller than the requested one. So stating a small offset here
will reduce the propability to reject such a key.

**hash_type**

List (or single scalar) of accepted hash algorithms used to sign the request.

Authentication
++++++++++++++

Signer on Behalf
#################

The section *authorized_signer_on_behalf* is used to define the certificates
which are accepted to do a "request on behalf". The list is given as a hash 
of hashes, were each entry is a combination of one or more matching rules.

Possible rules are subject, profile and identifier which can be used in any combination.
The subject is evaluated as a regexp against the signer subject, therefore any characters with
a special meaning in perl regexp need to be escaped! Identifier and profile are matched as is.
The rules in one entry are ANDed together. If you want to provide alternatives, add multiple
list items. The name of the rule is just used for logging purpose.

Challenge Password
##################

The request must carry the password in the challengePassword attribute.
The sample config above shows a static password example but it is also
possible to use request parameters to lookup a password using connectors::

    challenge:
       mode: bind
       value@: connector:scep.connectors.challenge
       args:
       - "[% context.cert_subject %]"

    connectors:
        challenge:
            class: Connector::Builtin::Authentication::Password
            LOCATION: /home/pkiadm/ca-one/passwd.txt

This will use the cert_subject to validate the given password against a list
found in the file /home/pkiadm/ca-one/passwd.txt. For more details, check the
man page of OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateChallenge

Renewal/Replace
###############

A request is considered to be a renewal if the request is *not* self-signed
but the signer subject matches the request subject. Renewal requests pass
authentication if the signer certificate is valid in the current realm and
neither revoked nor expired. You can allow expired certificates by setting
the *allow_expired_signer* policy flag.

Manual Authentication
#####################

If you set the *allow_man_authen* policy flag, request that fail any of the 
above authentication methods can be manually authenticated via the UI.

No Authentication
###################

To completly skip authentication, set *allow_anon_enroll* policy flag.

Subject Checking
++++++++++++++++

The policy setting *max_active_certs* gives the maximum allowed number
of valid certificates sharing the same subject. If the certificate count
after issuance of the current request will exceed this number, the 
workflow stops in the POLICY_PENDING state. There are several settings
that influence this check, based on the operation mode:

Initial Enrollment
##################

If you set the *auto_revoke_existing_certs* policy flag, all certificates
with the same subject *will be revoked* prior to running this check. This 
does not make much sense with *max_active_certs* larger than 1 as all 
certificates will be revoked as soon as a new enrollment is started! The
intended use is replacement of broken systems where the current certificate
is no longer used anyway.

Renewal
#######

If the certificate used to sign the renewal (see authentication) expires
within the period specified by *renewal_period*, it is not counted against
the limit.


Replace
#######

Same as renewal based on the *replace_period* parameter. See below for an
explanation of the *revoke_on_replace* feature.

Eligibility
+++++++++++

The default config has a static value of 1 for renewals and 0 for initial
requests. If you set *approval_points* to 1, this will result in an 
immediate issue of certificate renewal requests but requires operator 
approval on initial enrollments. 

Assume you want to use an ldap directory to auto approve initial requests
based on the mac address of your client::

    eligible:
        initial:
            value@: connector:your.connector
            args:
            - "[% context.cert_subject %]"
            - "[% context.url_mac %]"

    connectors:
        devices:
            ## This connector just checks if the given mac
            ## exisits in the ldap
            class: Connector::Proxy::Net::LDAP::Simple
            LOCATION: ldap://localhost:389
            base: ou=devices,dc=mycompany,dc=com
            filter: (macaddress=[% ARGS.1 %])
            binddn: cn=admin,dc=mycompany,dc=com
            password: admin
            attrs: macaddress

To have the mac in the workflow, you need to pass it with the request as an url
parameter to the wrapper: `http://host/scep/scep?mac=001122334455`.

For more options and samples, see the perldoc of
OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility

Approval
++++++++

A request is approved if it reaches the number of approvals defined by the
*approval_points* policy setting. As written above, you can use a data source
to get one approval point via the eligibility check. If a request has an
insufficient number of approvals, the workflow will stop and an operator 
must give an approval using the WebUI. By raising the approval points
value, you can also enforce a four-eyes approval. If you do not want manual
approvals, set the policy flag *allow_man_approv* to zero - all requests
that fail the eligibility check will be immediately terminated.

Certificate Configuration
-------------------------

SCEP Server Token
+++++++++++++++++

This is the cryptographic token used to sign and decrypt the SCEP 
communication itself. It is not related to the issuing process of
the requested certificates! 

The crypto configuration of a realm (crypto.yaml) defines a default token
to be used for all scep services inside this realm. In case you want
different servers to use different certificates, you can add additional
token groups and reference them from the config using the *token* key.
 
The value must be the name of a token group, which needs to be registered
as an anonymous alias::

    openxpkiadm alias --realm ca-one --identifier <identifier> --group ca-one-special-scep --gen 1

Note that you need to care yourself about the generation index. The token will
then be listed as anonymous group item::

    openxpkiadm alias --realm ca-one

    === anonymous groups ===
    ca-one-special-scep:
      Alias     : ca-one-special-scep-1
      Identifier: O9vtjge0wHpYhDpfko2O6xYtCWw
      NotBefore : 2014-03-25 15:26:18
      NotAfter  : 2015-03-25 15:26:18
 


Profile Selection / Certificate Template Name Extension
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

This feature was originally introduced by Microsoft and uses a Microsoft 
specific OID (1.3.6.1.4.1.311.20.2). If your request contains this OID 
**and** the value of this oid is listed in the profile map, the workflow
will use the given profile definition to issue the certificate. If no OID
is present or the value is not in the map, the default profile from the
server configuration is used.

The map is a hash list::

    profile_map:
        tlsv2: I18N_OPENXPKI_PROFILE_TLS_SERVER_v2
        client: I18N_OPENXPKI_PROFILE_TLS_CLIENT


Subject Rendering
+++++++++++++++++

By default the received csr is used to create the certificate "as is". To have
some sort of control about the issued certificates, you can use the subject
rendering engine which is also used with the frontend by setting a profile
style to be used:

    subject_style: enroll

The subject will be created using Template Toolkit with the parsed subject hash
as input vars. The vars hash will use the name of the attribute as key and pass
all values as array in order of appearance (it is always an array, even if the
attribute is found only once!). You can also add SAN items but there is no way
to filter or remove san items that are passed with the request, yet.

Example: The default TLS Server profile contains an enrollment section::
 
    enroll:
        subject: 
            dn: CN=[% CN.0 %],DC=Test Deployment,DC=OpenXPKI,DC=org

The issued certificate will have the common name extracted from the incoming
request but get the remaining path compontens as defined in the profile.


Revoke on Replace
+++++++++++++++++

If you have a replace request (signed renewal with signer validity between 
replace_window and renew_window), you can trigger the automatic revocation 
of the signer certificate. Setting a reason code is mandatory, supported 
values can be taken from the openssl man page (mind the CamelCasing), the
invalidity_time is optional and can be relative or absolute date as consumed 
by OpenXPKI::DateTime, any empty value becomes "now"::

    revoke_on_replace:
        reason_code: superseded
        invalidity_time: +000002
 
The above gives your friendly admins a 48h window to replace the certificates 
before they show up on the next CRL. It also works the other way round - 
assume you know a security breach happend on the seventh of april and you want
to tell this to the people::

    revoke_on_replace:
        reason_code: keyCompromise
        invalidity_time: 20140407

Note: Without any other measures, this will obviously enable an attacker 
who has access to a leaked key to obtain a new certificate. We used this
to replace certificates after the Heartbleed bug with the scep systems
seperated from the public network.

Misc
----

**workflow_type**

The name of the workflow that is used by this server instance. 

**response.getcacert_strip_root**

The scep standard is a bit unclear if the root should be in the chain or not.
We consider it a security risk (trust should be always set by hand) but as
most clients seem to expect it, we include the root by default. If you are 
sure your clients do not need the root and have it deployed, set this flag 
to 1 to strip the root certificate from the getcacert response.

The workflow context
--------------------

The workflow uses status flags in the context to take decissions. Flags are boolean if not stated otherwise. This is intended to be a debugging aid.

**csr_key_size_ok**

Weather the keysize of the csr matches the given array. If the key_size definition is missing, the flag is not set.

**have_all_approvals**

Result of the approval check done in CalcApproval.

**in_renew_window**

The request is within the configured renewal period.

**num_manual_authen**

The number of given manual authentications. Can override missing authentication on initial enrollment.

**scep_uniq_id_ok**

The internal request id is really unique across the whole system.

**signer_is_self_signed**

The signer and the csr have the same public key. Note: If you allow key renewal this might also be a renewal!

**signer_on_behalf**

The signer certificate is recognized as an authorized signer on behalf. See *authorized_signer_on_behalf* in the configuration section.

**signer_signature_valid**

The signature on the PKCS#7 container is valid.

**signer_sn_matches_csr**

The request subject matches the signer subject. This can be either a self-signed initial enrollment or a renewal!

**signer_status_revoked**

The signer certificate is marked revoked in the database.

**signer_trusted**

The PKI can build the complete chain from the signer certificate to a trusted root. It might be revoked or expired!

**signer_validity_ok**

The notbefore/notafter dates were valid at the time of validation. In case you have a grace_period set, a certificate is also valid if it has expired within the grace period.

**valid_chall_pass**

The provided challenge password has been approved.

**valid_kerb_authen**

Request was authenticated using kerberos (not implemented yet)

**csr_profile_oid**

The profile name as extracted from the Certificate Type Extension (Microsoft specific)


# Enrollment Workflow

The enrollment workflow is used by the SCEP, EST and RPC interface. The
details how to connect the workflow to the API differ but the general
configuration and operational modes are the same for all three subsystems.

## Operational Modes

It is important to understand that the default workflow has three operational
modes which are autodetected based on parameters of the request. It is a common
problem that the workflow does not behave as expected because you got into the
wrong operational mode due to a non-compliant client (e.g Cisco ASA).

### Initial Enrollment

Request a certificate for the first time. For SCEP this includes both
unauthenticated requests (no signer certificate at all) and self-signed
requests where the signer key matches the CSR key. The latter means the
certificate used for the outer signature must use the same key as the CSR.
Especially Cisco ASA fails here as the certificate subject does not match
the request subject, pushing the request into "On Behalf" mode instead.

For EST and RPC this is equivalent to an unauthenticated/unsigned TLS request.

### Renewal

Request renewal by sending a new request signed with the existing certificate.
This requires that the **full subject** of request and signer certificate
matches AND the new CSR uses a different key (reuse of keys is not supported).
With the default profiles the PKI will enforce the DC/O parts of the entity
certificates so this is a common problem when new certificates are created
using the old configuration. Best strategy is to create the new request from
the old certificate to ensure the subjects match.

### Enrollment On Behalf

Request a certificate with the help of a Trusted Third Party - the request
is signed using a certificate issued from the PKI which is qualified as
"Authorized Signer (see below)" for the given endpoint. This branch is
always choosen if the subject of request and signer do not match, so it is
often hit by accident when Renewal or Initial Enrollment are made with
"wrong" subjects.

For SCEP the signature on the SCEP PKCS7 container is the TTP, for EST/RPC
the TTP is the TLS client certificate used to make the connection. If you
use RPC with JSON Web Signature the certificate used to sign the JWT becomes
the TTP.

## Workflow Logic

The workflow validates incoming requests against five stages. Parameters
are described in detail in the section on policy settings.

**technical parameters:**
Check if key algorithm, key size and hash algorithm match the policy.
If any of those checks fails, the request is rejected.

**authentication:**
A request can either be self-signed and provide a challenge password
or use an HMAC for authentication or is signed by a trusted certificate
(renewal or "signer on behalf"). HMAC is evaluated first; if valid, the
challenge password is skipped. If HMAC is not configured, the challenge
password is tried next. You can also disable authentication or dispatch
unauthorized requests to an operator for review.

**subject duplicate check:**
The database is checked for valid certificates with the same subject.
If issuing the certificate would exceed the configured maximum count,
the request stops in the `PENDING_POLICY_VIOLATION` state. An operator
can then choose to: reevaluate the check (e.g. after revoking a conflicting
certificate), override the policy and proceed anyway, or reject the request.

**eligibility:**
The basic idea is to check requests based on the subject or additional
parameters against an external source to see if enrollment is possible.
The check counts against the approval point counter, the workflow does
not take any special action if the check fails.

**approval point:**
The first four stages are usually run in one step when the request
hits the server. Before the certificate is issued, the request must
have a sufficient number of approval points. Each operator approval
is worth one point. A passed eligibility check is also worth one.

## Sample Configuration

The workflow fetches all information from the configuration system at
`<subsystem>.<servername>` where the servername is taken from the wrapper
configuration.

Here is a complete sample configuration (found in `rpc/generic.yaml`). The
`export_certificate` is only applicable to the RPC wrapper, for EST and SCEP
you have to configure this on the frontend side.

The remainder of the configuration is the same for all subsystems:

```yaml
# Used in some dropdowns on the UI as name for this endpoint
label: Enrollment

# A renewal request is only accpeted if the used certificate will
# expire within this period of time.
renewal_period: "000060"

# Create certificates for initial requests with a short validity to
# allow an immediate renewal
initial_validity: "+000030"

# If the request was a replacement, optionally revoke the replaced
# certificate after a grace period
revoke_on_replace:
    reason_code: keyCompromise
    delay_revocation_time: "+000014"

# if you remove this section, any non-renewal request will be treated
# as an initial request, this works around non-standard MDM and devices
authorized_signer:
    rule1:
        # Full DN
        subject: CN=.+:pkiclient,.*
    rule2:
        # Full DN
            subject: CN=my.scep.enroller.com:generic,.*

policy:
    # Authentication Options
    # Initial requests need ONE authentication.
    # Activate Challenge Password and/or HMAC by setting the appropriate
    # options below.

    # if set requests can be authenticated by an operator
    allow_man_authen: 1

    # if set, no authentication is required at all and hmac/challenge is
    # not evaluated even if it is set/present in the request!
    allow_anon_enroll: 0

    # Approval
    # If not autoapproved, allow opeerator to add approval by hand
    allow_man_approv: 1

    # if the eligibiliyt check failed the first time
    # show a button to run a recheck (Workflow goes to PENDING)
    allow_eligibility_recheck: 0

    # Approval points requirede (eligibity and operator count as one point each)
    # if you set this to "0", all authenticated requests are auto-approved!
    approval_points: 1

    # The number of active certs with the same subject that are allowed
    # to exist at the same time, deducted by one if a renewal is seen
    # set to 0 if you dont want to check for duplicates at all
    max_active_certs: 1

    # If an initial enrollment is seen
    # all existing certificates with the same subject are revoked
    auto_revoke_existing_certs: 1

    # allows a "renewal" outside the renewal window, the notafter date
    # is aligned to the old certificate. Set revoke_on_replace option
    # to revoke the replaced certificate.
    # This substitutes the "replace_window" from the OpenXPKI v1 config
    allow_replace: 1

    # by default only the certificate identifier is written to the workflow
    # set to a true value to get the PEM encoded certificate in the context,
    # set to "chain" to get the issuer certificate and "fullchain" to get
    # the chain including the root certificate (key chain).
    export_certificate: chain

profile:
  cert_profile: tls_server
  cert_subject_style: enroll

# Mapping of names to OpenXPKI profiles to be used with the
# Microsoft Certificate Template Name Ext. (1.3.6.1.4.1.311.20.2)
profile_map:
    pc-client: tls_client
    tls-server: tls_server
    tls-client: tls_client
    tls-dual: tls_dual

# HMAC based authentication
hmac: verysecret

challenge:
    value: SecretChallenge

eligible:
    initial:
       value@: connector:rpc.enroll.connector.intranet
       args: '[% context.cert_subject_parts.CN.0 %]'

    renewal:
       value: 1

    onbehalf:
       value: 1

connector:
    intranet:
        class: Connector::Proxy::YAML
        # this file must have a key/value list with the key being
        # the subject and the value being a true value
        # e.g. "pc1234.example.org: 1"
        LOCATION: /home/pkiadm/cmdb.yaml
```

*The `renewal_period` value is interpreted as OpenXPKI::DateTime relative date but given without sign.*

## Workflow Configuration

### Test-Drive (INSECURE)

If you need a server that *just creates certificates*, use the following
policy section:

```yaml
policy:
    allow_anon_enroll: 1
    approval_points: 0
    max_active_certs: 0
    allow_replace: 0
    export_certificate: chain
```

**This will issue any certificate for any request - so do not use this in production**

### Authentication

#### Signer on Behalf

The section *authorized_signer* is used to define the certificates which
are accepted to do a "request on behalf". The list is given as a hash
of hashes, were each entry is a combination of one or more matching rules.

Possible rules are subject, profile and identifier which can be used in
any combination. The subject is evaluated as a regexp against the signer
subject, therefore any characters with a special meaning in perl regexp
need to be escaped! Identifier and profile are matched as is.
The rules in one entry are ANDed together. If you want to provide
alternatives, add multiple list items. The name of the rule is just used
for logging purpose.

#### Challenge Password

The request must carry the password in the challengePassword attribute.
The sample config above shows a static password example but it is also
possible to use request parameters to lookup a password using connectors:

```yaml
challenge:
   mode: bind
   value@: connector:scep.connectors.challenge
   args:
   - "[% context.cert_subject %]"

connectors:
    challenge:
        class: Connector::Builtin::Authentication::Password
        LOCATION: /home/pkiadm/democa/passwd.txt
```

This will use the cert_subject to validate the given password against a list
found in the file /home/pkiadm/democa/passwd.txt. For more details, check the
man page of OpenXPKI::Server::Workflow::Activity::Tools::ValidateChallengePassword

#### Renewal/Replace

A request is considered to be a renewal if the request is *not* self-signed
but the signer subject matches the request subject. Renewal requests pass
authentication if the signer certificate is valid in the current realm and
neither revoked nor expired.

#### Manual Authentication

If you set the *allow_man_authen* policy flag, request that fail any of the
above authentication methods can be manually authenticated via the UI.

#### No Authentication

To completly skip authentication, set *allow_anon_enroll* policy flag.

### Subject Checking

The policy setting *max_active_certs* gives the maximum allowed number
of valid certificates sharing the same subject. If the certificate count
after issuance of the current request will exceed this number, the
workflow stops in the PENDING_POLICY_VIOLATION state. If this parameter is
not set, no checks are done. There are several settings that influence this
check, based on the operation mode:

#### Initial Enrollment

If you set the *auto_revoke_existing_certs* policy flag, all certificates
with the same subject *will be revoked* prior to running this check. This
does not make much sense with *max_active_certs* larger than 1 as all
certificates will be revoked as soon as a new enrollment is started! The
intended use is replacement of broken systems where the current certificate
is no longer used anyway.

#### Renewal/Replace

If the request is a renewal or replacement request, it is allowed to
exceed the max_active_certs by one.

### Eligibility

The default config has a static value of 1 for renewals and 0 for initial
requests. If you set *approval_points* to 1, this will result in an
immediate issue of certificate renewal requests but requires operator
approval on initial enrollments.

Assume you want to use an ldap directory to auto approve initial requests
based on the mac address of your client:

```yaml
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
```

To have the mac in the workflow, you need to pass it with the request as an url
parameter to the wrapper: `http://host/scep/generic?mac=001122334455`.

For more options and samples, see the perldoc of
OpenXPKI::Server::Workflow::Activity::Tools::EvaluateEligibility

### Approval

A request is approved if it reaches the number of approvals defined by the
*approval_points* policy setting. As written above, you can use a data source
to get one approval point via the eligibility check. If a request has an
insufficient number of approvals, the workflow will stop and an operator
must give an approval using the WebUI. By raising the approval points
value, you can also enforce a four-eyes approval. If you do not want manual
approvals, set the policy flag *allow_man_approv* to zero - all requests
that fail the eligibility check will be immediately rejected.

### Profile Selection / Certificate Template Name Extension

This feature was originally introduced by Microsoft and uses a Microsoft
specific OID (1.3.6.1.4.1.311.20.2). If your request contains this OID
**and** the value of this oid is listed in the profile map, the workflow
will use the given profile definition to issue the certificate. If no OID
is present or the value is not in the map, the default profile from the
server configuration is used. This map is also used if the you pass the
*profile* as parameter in an RPC call.

The map is a hash list:

```yaml
profile_map:
    tlsv2: tls_server_v2
    client: tls_client
```

### Subject Rendering

Subject rendering is based on the profile and subject information given
in the config:

```yaml
profile:
    cert_profile: tls_server
    cert_subject_style: enroll
```

The subject will be created using Template Toolkit with the parsed subject hash
as input vars. The vars hash will use the name of the attribute as key and pass
all values as array in order of appearance (it is always an array, even if the
attribute is found only once!). You can also add SAN items but there is no way
to filter or remove san items that are passed with the request, yet.

Example: The default TLS Server profile contains an enrollment section:

```yaml
enroll:
    subject:
        dn: CN=[% CN.0 %],DC=Test Deployment,DC=OpenXPKI,DC=org
```

The issued certificate will have the common name extracted from the incoming
request but get the remaining path compontens as defined in the profile.

### Revoke on Replace

If you have a replace request (signed renewal with signer validity outside
the renewal window), you can trigger the automatic revocation of the signer
certificate. Setting a reason code is mandatory, supported
values can be taken from the openssl man page (mind the CamelCasing), the
`delay_revocation_time` is optional and can be relative or absolute date as consumed
by OpenXPKI::DateTime, any empty value becomes "now":

```yaml
revoke_on_replace:
    reason_code: superseded
    delay_revocation_time: '+000002'
```

The above gives your friendly admins a 48h window to replace the certificates
before they show up on the next CRL.

Note: Without any other measures, this will obviously enable an attacker
who has access to a leaked key to obtain a new certificate. We used this
to replace certificates after the Heartbleed bug with the scep systems
seperated from the public network.

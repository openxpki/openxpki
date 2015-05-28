Realm configuration
====================================

To create a new realm for your OpenXPKI installation, you need to create a
configuration for it. The fastest way is to copy ``config.d/realm.tpl`` to
``config.d/<realm_name>``. *realm_name* must match the name you gave the realm
in ``system.realms``.

The realm configuration consists of five major parts:

Authentication
    Configure which authentication mechanisms to use for the realm. If you use internal authentication methods, this also holds your user databases.

Crypto layer
    Define name and path of your keyfiles and settings for the crypto tokens used.

Profiles
    Anything related to your certificate and crl profiles

Publishing
    How and where to publish certificates and crls

Workflow
    Configuration data of the internal workflow engine.


Authentication
--------------

Authentication is done via authentication handlers, multiple handlers are combined to an authentication stack.

Stack
^^^^^

The authentication stacks are set below ``auth.stack``::

    User:
        description: I18N_OPENXPKI_CONFIG_AUTH_STACK_DESCRIPTION_USER
        handler:
        - User Password
        - Operator Password

The code above defines a stack *User* which internally uses two handlers for authentication. You can define any number of stacks and reuse the same handlers inside. You must define at least one stack.


Handler
^^^^^^^

A handler consists of a perl module, that provides the authentication mechanism. The name of the handler is used to be referenced in the stack definition, mandatory entries of each handler are *type* and *label*. All handlers are defined below OpenXPKI::Server::Authentication, where *type* is equal to the name of the module.

Here is a list of the default handlers and their configuration sets.

**anonymous user**

If you just need an anonymous connection, you can use the *Anonymous* handler. ::

    Anonymous:
        type: Anonymous
        label: Anonymous

    System:
        type: Anonymous
        label: System
        role: System

If no role is provided, you get the anonymous role. **Do never set any other role than system, unless you exactly know what you are doing!**

**x509 based authentication**

There are two handlers using x509 certificates for authentication. *X509Client* uses the SSL client authentication feature of apache/mod_ssl while *X509Challenge* sends a challenge to be signed by the browser. Both handlers pass the signer certificate to a validation function that cryptographically checks the chain and tests the chain against a list of trusted anchors.

The configuration is the same for both handlers (apart from the class name)::

    Certificate:
        type: ClientX509/ChallengeX509
        label: Certificate
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_CERTIFICATE_WEBSERVER
        role:
            default: User
            handler@: connector:auth.connector.role
            argument: cn
        realm:
        - ca-one
        cacert:
        - cert_identifier of external ca cert

The role assignment is done by querying the connector specified by *handler* using the certificates component *argument*. Possible arguments are "cn", "subject" and "serial". The value given by *default* is assigned if no match is found by the handler. If you do not specify a handler but a default role, you get a static role assignment for any matching certificate.

For the trust anchor you have consider two different situations:

#. If the certificates originate from the OpenXPKI instance itself, list the realms which issue them below *realm*.
#. If you have certificates from an external ca, import the ca certificate with the ``openxpkiadm`` utility and put its certificate identifier below *cacert*.

Both lists can be combined and accept any number of items.

**Note**: OpenXPKI uses a third party tool named openca-sv to check the x509 signature. You need to build that by your own and put it into /usr/bin. The source is available at http://www.openca.org/projects/openca/tools-sources.shtml.

**password database handler**

The password database handler allows to specify user/password/role pairs directly inside the configuration. ::

    Password:
        type: Password
        label: User Password
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_PASSWORD
        user:
            John Doe:
                digest: "{SSHA}TZXM/aqflDDQAmSWVxSDVWnH+NhxNU5w"
                role: User
            root:
                digest: "{SSHA}+u48F1BajP3ycfY/azvTBqprsStuUnhM"
                role: CA Operator
            raop:
                digest: "{SSHA}ejZpY22dFwjVI48z14y2jYuToPRjOXRP"
                role: RA Operator

The passwords are hashed, the used hash algorithm is given as prefix inside the curly brackets. You should use only *SSHA* which is "salted sha1". For compatibility we support plain sha (sha1), md5, smd5 (salted md5) and crypt. You can created the salted passwords using the openxpkiadm CLI tool.

If you plan to use static passwords for a larger amount of users, you should consider to use a connector instead::

    Password:
        type: Password
        label: User Password
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_PASSWORD
        user@: connector:auth.connector.userdb

Define the user database file inside auth.connector.yaml::

    userdb:
        class: Connector::Proxy::YAML
        LOCATION: /home/pkiadm/ca-one-userdb.yaml

The user file has the same structure as the *user* section above, the user names are the on the top level::

    root:
        digest: "{SSHA}+u48F1BajP3ycfY/azvTBqprsStuUnhM"
        role: CA Operator
    raop:
        digest: "{SSHA}ejZpY22dFwjVI48z14y2jYuToPRjOXRP"
        role: RA Operator

You can share a user database file within realms.

**authentication connectors**

There is a family of authentication connectors. The main difference against
other connector is, that the password is passed as a parameter and is not
part of the path. Check for connectors starting with Connector::Builtin::Authentication.
The connector only validates the password, therefore the role must be set in
the configuration (same for all users handled by this item)::

    Password Connector:
        type: Connector
        label: User Password
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_PASSWORD
        role: User
        source@: connector:auth.connector.localuser

**external authentication**

If you have a proxy or sso system in front of your OpenXPKI server that authenticates your users, the external handler can be used to set the user information::

    External Dynamic Role:
        type: External
        label: External Dynamic Role
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_EXTERNAL
        command: echo -n $PASSWD
        # if this field is empty then the role is determined dynamically -->
        role: ''
        pattern: x
        replacement: x
        env:
           LOGIN: __USER__
           PASSWD: __PASSWD__


TODO: This needs some useful example code.

Workflow ACL
^^^^^^^^^^^^

The Workflow-ACL set is located at ``auth.wfacl`` and controls which workflows a user can access. The rules are based on the role of the user and distinguish between creating a new and accessing an exisiting workflow.

**workflow creation**

To determine what workflows a user can create, just list the names of the workflows under the create key. ::

    User:
        create:
        - I18N_OPENXPKI_WF_TYPE_CERTIFICATE_RENEWAL_REQUEST
        - I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST
        - I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST
        - I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE


**unconditional workflow access**

The access privileg takes the workflow creator into account. To get access to all existing workflows regardless of the creator, use a wildcard pattern::

    User:
        access:
            I18N_OPENXPKI_WF_TYPE_CERTIFICATE_RENEWAL_REQUEST:
                creator: .*


**conditional workflow access**

To show a user only his own workflows, use the special word *self*::

    User:
        access:
            I18N_OPENXPKI_WF_TYPE_CERTIFICATE_RENEWAL_REQUEST:
                creator: self


**workflow context filter**

Sometimes the workflow context contains items, you don't want to show to the user. You can specify a regular expression to show or hide certain entries. The regex is applied to the context key::

    User:
        access:
            I18N_OPENXPKI_WF_TYPE_PASSWORD_SAFE:
                creator: self
                context:
                    show: .*
                    hide: encrypted_.*


The given example shows everything but any context items that begin with "encrypted\_". The filters are additive, so a key must match the show expression but must not match the hide expression to show up. *Note*: No setting or an empty string for *show* results in no filtering! To hide the whole context set a wildcard ".*" for *hide*.


Crypto layer
------------

group assignment
^^^^^^^^^^^^^^^^

You must provide a list of token group names at ``crypto.type`` to tell the system which token group it should use for a certain task. The keys are the same as used in ``system.crypto.tokenapi`` (see Crypto layer (global)). See TODO for a detailed view how the token assignment works. ::

    type:
      certsign: ca-one-certsign
      datasafe: ca-one-vault
      scep: ca-one-scep

token setup
^^^^^^^^^^^

Any token used within OpenXKI needs a corresponding entry in the realm's token configuration at ``crypto.token``. The name of the token is the alias name you used while registering the correspondig certificate. ::

    token:
      ca-one-certsign:
        backend: OpenXPKI::Crypto::Backend::OpenSSL

        key: /etc/openxpki/ssl/ca-one/ca-one-certsign-1.pem

        # possible values are OpenSSL, nCipher, LunaCA
        engine:         OpenSSL
        engine_section: ''
        engine_usage:   ''
        key_store:      OPENXPKI

        # OpenSSL binary location
        shell: /usr/bin/openssl

        # OpenSSL binary call gets wrapped with this command
        wrapper: ''

        # random file to use for OpenSSL
        randfile: /var/openxpki/rand

        # Secret group
        secret: default

The most important setting here is *key* which must be the absolute filesystem path to the keyfile. The key must be in PEM format and is protected by a password. The password is taken from the secret group mentioned by *secret*. See TODO for the meaning of the other options.

**using inheritance**

Usually the tokens in a system share a lot of properties. To simplify the configuration, it is possible to use inheritance in the configuration::

    token:
        default:
            backend: OpenXPKI::Crypto::Backend::OpenSSL
            ......
            secret: default

        server-ca-1:
            inherit: default
            key: /etc/openxpki/ssl/ca-one/ca-one-certsign-1.pem
            secret: gen1pass

        server-ca-2:
            inherit: default
            key: /etc/openxpki/ssl/ca-one/ca-one-certsign-2.pem


Inheritance can daisy chain profiles. Note that inheritance works top-down and each step replaces all values that have not been defined earlier but are defined on the current level. Therefore you should not use undef values but the empty string to declare an empty setting.

You can use template toolkit to autoconfigure the ``key`` property, this way you can roll over your key without modifying your configuration.

The example above will then look like::

    token:
        default:
            backend: OpenXPKI::Crypto::Backend::OpenSSL
            key: /etc/openxpki/ssl/ca-one/[% ALIAS %].pem
            ......
            secret: default

        server-ca-1:
            inherit: default
            secret: gen1key

        server-ca-2:
            inherit: default

If you need to name your keys according to a custom scheme, you also have GROUP (ca-one-certsign) and
GENERATION (1) available for substitution.

secret groups
^^^^^^^^^^^^^

A secret group maintain the password cache for your keys and PINs. You need to setup at least one secret group for each realm. The most common version is the plain password::

    secret:
      default:
        label: One Piece Password
        method: plain
        cache: daemon


This tells the OpenXPKI daemon to ask for the default only once and then store it "forever". If you want to have the secret cleared at the end of the session, set *cache: session*.

To increase the security of your key material, you can configure secret splitting (k of n). ::

    secret:
      ngkey:
        label: Split secret Password
        method: split
        total_shares: 5
        required_shares: 3
        cache: daemon

TODO: How to create the password segments?

If you have a good reason to put your password into the configuration, use the *literal* type::

    secret:
      insecure:
        label: A useless Password
        method: literal
        value: my_not_so_secret_password
        cache: daemon


Profiles
--------

certificates
^^^^^^^^^^^^

There is a TODO:link seperate section about certificate profile configuration.

certificate revocation list
^^^^^^^^^^^^^^^^^^^^^^^^^^^

A basic setup must provide at least a minimum profile for crl generation at ``crl.default``::

    digest: sha1
    validity:
        nextupdate: +000014
        renewal: +000003

The *nextupdate* value gives the validity of the created crl (14 days). The *renewal* value tells OpenXPKI how long before the expiry date of the current crl the system is allowed to create a new one. If you set this to a value larger than *nextupdate*, a new crl is created every time you trigger a new crl creation workflow. Note: If a certificate becomes revoked, the renewal interval is not checked.


**crl at "end of life"**

Once your ca certificate exceeds its validity, you are no longer able to create new crls (at least if you are using the shell modell). OpenXPKI allows you to define a different validity for the last crl, which is taken if the next calculated renewal time will exceed the validity of the ca certificate::

    validity:
        nextupdate: +000014
        renewal: +000003
        lastcrl: 20301231235900


**crl extensions**

The following code shows the full set of supported extensions, you can skip what you do not need::

    extensions:
        authority_info_access:
            critical: 0
            ca_issuers: http://myca.mycompany.com/[% CAALIAS.ALIAS %]/cacert.pem
            ocsp:
            - http://ocsp1.mycompany.com/
            - http://ocsp2.mycompany.com/

        authority_key_identifier:
            critical: 0
            keyid:  1
            issuer: 1


        issuer_alt_name:
            critical: 0
            # If the issuer has no subject alternative name, copying returns
            # an empty extension, which is problematic with both RSA SecurId
            # tokens and Cisco devices!
            copy: 0

There are two  specialities in handling the *ca_issuers* and *ocsp* entries in the *authority_info_access* section:

1. You can pass either a list or a single scalar to each item.
2. For each item, template expansion based on the signing ca certificate is available. See TODO:link for details.

The ``CAALIAS`` hash also offers the components of the alias in GENERATION and GROUP.

Publishing
----------

Publishing of certificates and crl is done via connectors (TODO:link). The default workflows look for targets at ``publishing.entity`` and ``publishing.crl``. Each target can contain a list of key-value pairs where the value points to a valid connector item while the keys are used for internal logging::

    entity:
        int-repo@: connector:publishing.connectors.ldap
        ext-repo@: connector:publishing.connectors.ldap-ext

    crl:
        crl@: connector:publishing.connectors.cdp


**certificate publishing**

The OpenXPKI packages ship with a sample configuration for LDAP publication but you might include any other connector. The publication workflow appends the common name of the certificate to the connector path and passes a hash containing the subject (*subject*) and the DER (*der*) and PEM (*pem*) encoded certificate.

The configuration block looks like this::

    connectors:
        ldap-ext:
            class: Connector::Proxy::Net::LDAP::Single
            LOCATION: ldap://localhost:389
            base: ou=people,dc=mycompany,dc=com
            filter: (|(mail=[% ARG %]) (objectCategory=person))
            binddn: cn=admin,dc=mycompany,dc=com
            password: secret
            attrmap:
                der: usercertificate;binary

            create:
                basedn: ou=people,dc=mycompany,dc=com
                rdnkey: cn

            schema:
                cn:
                    objectclass: inetOrgPerson
                    values:
                        sn: copy:self
                        ou: IT Department

Let's explain the parts.

::

    class: Connector::Proxy::Net::LDAP::Single
    LOCATION: ldap://localhost:389
    base: ou=people,dc=mycompany,dc=com
    filter: (|(mail=[% ARG %]) (objectCategory=person))
    binddn: cn=admin,dc=mycompany,dc=com
    password: secret

Use the Connector::Proxy::Net::LDAP::Single package and use *cn=admin,dc=mycompany,dc=com* and *secret* to connect with the ldap server at *ldap://localhost:389* using *ou=people,dc=mycompany,dc=com* as the basedn. Look for an entry of class person where the mailadress is equal to the common name of the certificate.

::

    attrmap:
        der: usercertificate;binary

Publish the content of the internal key *der* to the ldap attribute *usercertificate;binary*.

::

    create:
        basedn: ou=people,dc=mycompany,dc=com
        rdnkey: cn

This enables the auto-creation of non-existing nodes. The dn of the new node is create from the basedn and the new component of class "cn" set to the path-item which was passed to the connector (in our example the mailadress). You also need to pass the structural information for the node to create.

::

    schema:
        cn:
            objectclass: inetOrgPerson
            values:
                sn: copy:self
                ou: IT Department


**crl publishing**

The crl publication workflow appends the common name of the ca certificate to the connector path and passes a hash containing the subject (*subject*), the components of the parsed subject as hash (*subject_hash*) and the DER (*der*) and PEM (*pem*) encoded crl.

The default configuration comes with a text-file publisher for the crl::

    cdp:
        class: Connector::Builtin::File::Path
        LOCATION: /var/www/openxpki/myrealm/crls/
        file: "[% ARGS %].crl"
        content: "[% pem %]"

If the dn of your current ca certificate is like "cn=My CA1,ou=ca,o=My Company,c=us", this connector writes the PEM encoded crl to the file */var/www/openxpki/myrealm/crls/My CA1.crl*


Notification
------------

Notifications are triggered from within a workflow. The workflow just calls the
notification layer with the name of the message which should be send, which can
result in no message or multiple messages on different communication channels.

The configuration is done per realm at ``notification``. Supported connectors
are Mail via SMTP (plain and html) and RT Request Tracker
(using the RT::Client::REST module from CPAN). You can use an arbitrary number
of backends, where each one has its own configuration at ``notification.mybackend``.

Most parts of the messages are customized using the Template Toolkit. The list
of available variables is given at the end of this section.

Sending mails using SMTP
^^^^^^^^^^^^^^^^^^^^^^^^

You first need to configure the SMTP backend parameters::

    backend:
        class: OpenXPKI::Server::Notification::SMTP
        host: localhost
        port: 25
        username: smtpuser
        password: smtpsecret
        debug: 0
        use_html: 0

Class is the only mandatory parameter, the default is localhost:25 without
authentication. Debug enables the Debug option from Net::SMTP writing to the
stderr.log which can help you to test/debug mail delivery. To use html
formatted mails, you need to install *MIME::Lite* and set *use_html: 1*.
The handler will fall back to plain text if MIME::Lite can not be loaded.

The mail templates are read from disk from, you need to set a base directory::

    template:
        dir:   /home/pkiadm/ca-one/email/

Below is the complete message configuration as shipped with the default
issuance workflow::

    default:
        from: no-reply@mycompany.com
        reply: helpdesk@mycompany.com
        to: "[% cert_info.requestor_email %]"
        cc: helpdesk@mycompany.com

    message:
        csr_created:   # The message Id as referenced in the activity
            user:   # The internal handle for this thread
                template: csr_created_user
                subject: CSR for [% cert_subject %]
                prefix: PKI-Ticket [% meta_wf_id %]
                images:
                    banner: head.png
                    footer: foot.png

            raop:      # Another internal handle for a second thread
                template: csr_created_raop  # Suffix .txt is always added!
                to: reg-office@mycompany.com
                cc: ''
                reply: "[% cert_info.requestor_email %]"
                subject: CSR for [% cert_subject %]

        csr_rejected:
            user:
                template: csr_rejected
                subject: CSR rejected for [% cert_subject %]

        cert_issued:
            user:
                template: cert_issued
                subject: certificate issued for [% cert_subject %]


The *default* section is not necessary but useful to keep your config short and
readable. These options are merged with the local ones, so any local variable is
possible and you can overwrite any default at the local configuration (to clear
a setting use an empty string, the images hash is NOT merged recursively).

**the idea of threads**

You might have recognized that there are two blocks below ``messages.csr_created``.
Those are so called *threads*, which combine messages sent at different times
to share some common settings. With the first message of a thread the values given
for to, cc and prefix are persisted so you can ensure that all messages
that belong to a certain thread go to the same receipients using the same subject
prefix. **Note, that settings to those options in later messages are ignored!**

**receipient information**

The primary receipient and a from address are mandatory:

- to: The primary receipient, single value, parsed using TT
- from: single value, NOT parsed

Additional receipients and a seperate Reply-To header are optional:

- cc: comma seperated list, parsed using TT
- reply: single value, NOT parsed

All values need to be rfc822 compliant full addresses.

**composing the subject**

The subject is parsed using TT. If you have specified a prefix, it is automatically prepended.

**composing the message body**

The body of a message is read from the filename specified by *template*, where the
suffix '.txt' is always apppended. So the full path for the message at
``messages.csr_created.user`` is */home/pkiadm/ca-one/email/csr_created_user.txt*.

**html messages**

If you use the html backend, the template for the html part is read from
*csr_created_user.html*. It is allowed to provide either a text or a html
template, if both files are found you will get a multipart message with both
message parts set. Make sure that the content is the same to avoid funny issues ;)

It is possible to use inline images by listing the image files with the *images*
key as key/value list. The key is the internal identifier, to be used in the html
template, the value is the name of the image file on disk.

With a config of::

    user:
        template: csr_created_user
        ....
        images:
            banner: head.png
            footer: foot.png

You need to reference the image in the html template like this::

    <body>
        <img src="cid:banner" title="My Company Logo Banner" />
        .....
        <img src="cid:footer" title="My Company Logo Footer" />
    </body>

The images are pulled from the folder *images* below the template directory,
e.g. */home/pkiadm/ca-one/email/images/head.png*. The files must end on
gif/png/jpg as the suffix is used to detect the correct image type.



RT Request Tracker
^^^^^^^^^^^^^^^^^^

The RT handler can open, modify and close tickets in a remote RT system using the
REST interface. You need to install RT::Client::REST from CPAN and setup the connection::

    backend:
        class: OpenXPKI::Server::Notification::RT
        server: http://rt.mycompany.com/
        username: pkiuser
        password: secret
        timeout: 30

The timeout value is optional with a default of 30 seconds.

As the SMTP backend, it uses templates on disk to build the ticket contents, so
we also need to set the template directory::

    template:
        dir:   /home/pkiadm/ca-one/rt/

You can share the templates for SMTP and RT handler and reuse most parts of your configuration,
but note that the syntax is slightly different from SMTP. Here is the complete
message configuration as shipped with the default issuance workflow::

    message:
        csr_created:  # The message Id as referenced in the activity
            main:     # The internal handle for this ticket
                - action: open
                  queue: PKI
                  owner: pki-team
                  subject: New CSR for [% cert_subject %]
                  to: "[% cert_info.requestor_email %]"
                  template: csr_created
                  priority: 1

                - action: comment
                  template: csr_created_comment
                  status: open

        csr_approved:
            main:
                - action: update
                  status: working

        csr_rejected:
            main:
                - action: correspond
                  template: csr_rejected
                  priority: 10

        cert_issued:
            main:
                - action: comment
                  template: cert_issued_internals

                - action: correspond
                  template: cert_issued
                  status: resolved


The RT handler also makes use of threads, where each thread is equal to one
ticket in the RT system. The example uses only one thread = one ticket.
Each message can have multiple threads and each thread consists of at least
one action.

**Create a new ticket**

You should make sure that a ticket is created before you work with it!
The minimum information required to open a ticket is::

    action: open
    queue: PKI
    owner: pki-team
    subject: New CSR for [% cert_subject %]
    to: "[% cert_info.requestor_email %]"

The *to* field must be an email address, which is used to fill the *requestor*
field in RT.

Additional fields are:

- cc: comma sep. list of email addresses to be assigned to the ticket, parsed with TT
- template: filename for a TT template, used as inital text for the ticket (.txt suffix is added)
- priority: priority level, usually a numeric value
- status: ticket status, usually one of "new", "open", "resolved", "stalled", "rejected", and "deleted".

**comment or correspond to a ticket**

The maximum configuration is::

    action:   comment  # or "correspond"
    status:   open     # optional
    priority: 5        # optional
    template: csr_created_comment  # .txt is added

For *comment* the result of the parsed template is added to the ticket history.

For *correspond* the result is also mailed to the ticket receipients (this
is a feature of RT, we dont send any mails).

Note: If the template parser returns an empty string, no operation is done on the ticket.

**update status/priority without text**

The *update* action allows you to set status/priority without creating a text
entry in the history::

    action: update
    status: stalled
    priority: 0

You can call update with either status or priority or both.

**setting custom fields**

You can set custom field values using the update action. Any key/value pair in
the block (except the ones above) is considered to be a custom field. The values
are parsed using TT::

    action: update
    priority: 3
    custom-field1: My custom value
    custom-field2: My other custom value

Note: This feature is untested!

**closing a ticket**

You can close a ticket with the above commands by setting the status-flag.
For convenience there is a shortcut, setting the status to "resolved"::

    action: close


Template Variables
^^^^^^^^^^^^^^^^^^

The notification handler injects those values into the template parser on any invocation.

**realm info**

- meta_pki_realm (key of the current realm)
- meta_label (verbose realm name as defined at ``system.realms.$realm.label``)
- meta_baseurl (baseurl as defined at ``system.realms.$realm.baseurl``)

**request related context values (scalars)**

- csr_serial
- cert_subject
- cert_identifier
- cert_profile

**request related context values (hashes)**

- cert_subject_parts
- cert_subject_alt_name
- cert_info
- approvals

**misc**

- creator
- requestor (real name of the requestor, if available assembled from cert_info.requestor_gname + requestor_name, otherwise the word "unknown")

**Certificate Info Plugin**

The default install also provides a plugin to get detailed informations on a certificate::

  [% USE Certificate %]

  Serial: [% Certificate.serial(cert_identifier) %]
  Hex Serial: [% Certificate.serial_hex(cert_identifier) %]
  CSR: [% Certificate.csr_serial(cert_identifier) %]
  Issuer: [% Certificate.issuer(cert_identifier) %]
  Status: [% Certificate.status(cert_identifier) %]

  Body-Subject: [% Certificate.body(cert_identifier, 'Subject') %]

The body method will return any field of the body structure offered by the get_cert api method. Fore further info check the modules documentation (OpenXPKI::Template::Plugin::Certificate).


Workflow
--------

The definition of the workflows is still in the older xml format, already used in older OpenXPKI releases but its management is included into the connector now. The XML files are located in the folder named *_workflow* (**note the underscore!**) in the top level direcotry of the realm. If you are upgrading from an older installation, you can just move your old workflow*.xml files here *and* add an outer "openxpki" tag to the *workflow.xml* file.



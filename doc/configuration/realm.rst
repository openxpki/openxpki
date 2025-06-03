Realm
=====

In order to create a new realm you must create a new directory below
``config.d/realm`` with the internal name of the realm. While it is
possible to just create a symlink or copy from the realm.tpl directory
we recommend to read the instructions in the Quickstart document as this
approach gives you the best options for later upgrades of the
configuration.

When finished add a new section in the file ``system/realms.yaml`` where
the new section key is identical to the new realm directory name used for
the realm directory. Change the new realm section entries to match the
desired values for the new realm.
Also make sure to add your new realm in ``client.d/service/webui/default.yaml`` under ``realm.map`` and add your own realm so it shows up when selecting a realm.

Please note that you might need to perform additional steps based on the
overall configuration options such as creating templates, static content
or mapping items. Those should be outlined in the configurations setup
document.

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

The realm's authentication combines the configured authentication handlers to offer different authentication stacks. On the login page, the entries of the stack are shown and a user can choose between them. The stacks are configured in the file located in ``<realm-basedir>/auth/stack.yaml``. If, for example, one would like to enable only anonymous logins and password based logins, this file's contents could be as follows::

    Anonymous:
        label: Guest Login
        handler: Anonymous
        type: anon

    User:
        label: User Login
        type: passwd
        handler:
          - Operator Password
          - User Password

In this configuration, the realm offers two login stacks, namely *Anonymous* and *User*.
The stack *Anonymous* uses the Handler_ ``Anonymous`` and the logins
using the stack *User* may be performed by both handlers ``Operator Password`` and
``User Password``. Therefore, when selecting this variant, both logins with credentials
configured for ``Operator Password`` and for ``User Password`` are supported. You can define
any number of stacks and reuse the same handlers inside. You must define at least one stack.

**Advanced Usage**

Use the TLS Client Certificate from the HTTPS connection::

    Certificate:
        handler: Certificate
        type: x509

Use the REMOTE_USER field from basic auth, optionally pass additonal ENV keys from advanced auth modules::

    BasicAuth:
        handler: NoAuth
        type: client
        envkeys:
            email: AUTH_PROVIDER_email_field


Handler
^^^^^^^

A handler consists of a perl module, that provides the authentication mechanism. The name of
the handler is used to be referenced in the stack definition, mandatory entries of all handlers
is *type*. All handlers are defined below OpenXPKI::Server::Authentication, where *type* is equal
to the name of the module.

Here is a list of some handlers and their configuration sets, more can be found in the sample
configuration. Extensive documentation can be found in the perldoc for the classes.

**Anonymous user**

If you just need an anonymous connection, you can use the *Anonymous* handler. ::

    Anonymous:
        type: Anonymous
        # the verbose name is shown in the UI
        name: Guest User

    System:
        type: Anonymous
        role: System

If no role is provided, you get the anonymous role. **Do never set any other role than system, unless you exactly know what you are doing!**

**x509 based authentication**

*X509* uses the SSL client authentication feature of apache/mod_ssl. It passes the signer certificate to a validation function that cryptographically checks the chain and tests the chain against a list of trusted anchors.

The configuration is the same for both handlers (apart from the class name)::

    Certificate:
        type: ClientX509
        role: User
        trust_anchor:
            realm: userca


Please check `perldoc OpenXPKI::Server::Authentication::X509` for details.

**Password database handler**

The password database handler allows to specify user/password/role pairs directly inside the configuration. ::

    Password:
        type: Password
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

The passwords are hashed, the used hash algorithm is given as prefix inside the curly brackets. You should use only *SSHA* which is "salted sha1". For compatibility we support plain sha (sha1), md5, smd5 (salted md5) and crypt. You can created the salted passwords using the openxpkiadm CLI tool (``openxpkiadm hashpwd``). Alternatively, for batch processing, a *salted sha1* password could be generated using openssl::

   salt="$(openssl rand -base64 3)"
   password="secretpassword"
   echo -n $(echo -n "$password$salt" | openssl sha1 -binary)$salt | openssl enc -base64

*Note*: As of v3.10 we also directly support the format of the `openssl passwd` command starting with the Dollar sign.

If you plan to use static passwords for a larger amount of users, you should consider to use a connector instead::

    Password:
        type: Password
        user@: connector:auth.connector.userdb

Define the user database file inside auth.connector.yaml::

    userdb:
        class: Connector::Proxy::YAML
        LOCATION: /home/pkiadm/democa-userdb.yaml

The user file has the same structure as the *user* section above, the user names are the on the top level::

    root:
        digest: "{SSHA}+u48F1BajP3ycfY/azvTBqprsStuUnhM"
        role: CA Operator
    raop:
        digest: "{SSHA}ejZpY22dFwjVI48z14y2jYuToPRjOXRP"
        role: RA Operator

You can share a user database file within realms.

**Authentication connectors**

There is a family of authentication connectors. The main difference against
other connector is, that the password is passed as a parameter and is not
part of the path. Check for connectors starting with Connector::Builtin::Authentication.
The connector only validates the password, therefore the role must be set in
the configuration (same for all users handled by this item)::

    Password Connector:
        type: Connector
        role: User
        source@: connector:auth.connector.localuser

An example config to authenticate RA Operators against ActiveDirectory using their company mail address and windows password including check of a group membership (this is just the authentication, set the role in the handler config)::

    raop-ad:
        class: Connector::Builtin::Authentication::LDAP
        LOCATION: ldap://ad.company.com
        base: dc=company,dc=loc
        binddn: cn=binduser
        password: secret
        filter: "(&(mail=[% LOGIN %])(memberOf=CN=RA Operator,OU=SecurityGroups,DC=company,DC=loc))"


**External authentication**

If you have a proxy or sso system in front of your OpenXPKI server that authenticates your users, the external handler can be used to set the user information::

    ExternalAuth:
        type: NoAuth
        role: User

Crypto layer
------------

group assignment
^^^^^^^^^^^^^^^^

You must provide a list of token group names at ``crypto.type`` to tell the system which token group it should use for a certain task. The keys are the same as used in ``system.crypto.tokenapi`` (see Crypto layer (global)). See TODO for a detailed view how the token assignment works. ::

    type:
      certsign: ca-certsign
      datasafe: vault
      scep: scep

token setup
^^^^^^^^^^^

Any token used within OpenXPKI needs a corresponding entry in the realm's token configuration at ``crypto.token``. The name of the token is the alias name you used while registering the correspondig certificate. ::

    token:
      democa-certsign:
        backend: OpenXPKI::Crypto::Backend::OpenSSL

        key: /etc/openxpki/local/keys/democa/ca-certsign-1.pem

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
            key: /etc/openxpki/local/keys/democa/ca-certsign-1.pem
            secret: gen1pass

        server-ca-2:
            inherit: default
            key: /etc/openxpki/local/keys/democa/ca-certsign-2.pem


Inheritance can daisy chain profiles. Note that inheritance works top-down and each step replaces all values that have not been defined earlier but are defined on the current level. Therefore you should not use undef values but the empty string to declare an empty setting.

You can use template toolkit to autoconfigure the ``key`` property, this way you can roll over your key without modifying your configuration.

The example above will then look like::

    token:
        default:
            backend: OpenXPKI::Crypto::Backend::OpenSSL
            key: /etc/openxpki/local/keys/democa/[% ALIAS %].pem
            ......
            secret: default

        server-ca-1:
            inherit: default
            secret: gen1key

        server-ca-2:
            inherit: default

If you need to name your keys according to a custom scheme, you also have GROUP (ca-signer) and
GENERATION (1) available for substitution. The certificate identifier is also available via IDENTIFIER.

**token in datapool**

Instead of having the tokens key files on the filesystem it is possible to
store them in the datapool. Please be aware of the security implications of
putting your CAs PRIVATE KEYS into the datapool which is readable by anybody
with access to the database or the openxpki socket!

You must set the attribute ``key_store`` to ``DATAPOOL`` and provide the
name of the used datapool key using the ``key`` attribute::

    scep:
        inherit: default
        key_store: DATAPOOL
        key: "[% ALIAS %]"

This will read the SCEP key from the datapool, the used namespace is
``sys.crypto.keys``. You must import the key yourself, e.g. from the CLI::

    openxpkicli set_data_pool_entry --arg namespace=sys.crypto.keys \
        --arg key=scep-1 \
        --arg encrypt=1 \
        --filearg value=file_with_key.pem

Using the datapool encryption hides the value of the key from database
admins but still exposes it in clear text to anybody with access to the
command line tool! It should be obvious that you can not store the
data-vault token this way as it is needed to decrypt the datapool items!

Starting with v3.8 the ``openxpkiadm alias`` command can handle key imports
internally, you can load the certificate and key in one step::

    openxpkiadm alias --realm democa --token scep \
        --file democa-scep.crt --key democa-scep.pem

**HSM via PKCS#11**

Tokens may be maintained by HSMs as well. For HSMs a standardized interface called PKCS#11 is defined.
OpenSSL supports this interface as well through its *pkcs11* engine.
This OpenSSL engine is supplied by the OpenSC and has to be configured in OpenXPKI.

To use PKCS#11 token in OpenXPKI the following settings has to be made:

* The engine has to be set to *PKCS11*. This causes OpenXPKI to use OpenSSL's PKCS#11 engine.
* The key has to correspond to the key's identification of the HSM.
  For example when the YubiHSM2 is used, the string *slot_0-label_issuer_key* would correspond to a stored key with the label *issuer_key*.
* As *engine_section* one can define how OpenSSL accesses the HSM.
  OpenXPKI always generates OpenSSL configurations on the fly when needed and if this token is accessed, the contents of OpenSSL's ``[engine_section]`` are pasted in this configuration file.
  To define which passphrase is used to unlock the HSM, the configuration
  parameter *PIN* should be set as shown in the example.
  OpenXPKI ensures to replace any occurrence of the string *__PIN__* with the
  corresponding secret.
* The value of *engine_usage* defines when the engine should be used.
  Often *ALWAYS* is the preferred setting.

To use PKCS#11 tokens in OpenXPKI, the backend of the token has to be set to *PKCS11*.::

   token:
     signer:
       backend: OpenXPKI::Crypto::Backend::OpenSSL
       key: "slot_0-label_issuer_key"
       engine: PKCS11
       engine_section: |
         engine_id              = pkcs11
         dynamic_path           = /usr/lib/engines/engine_pkcs11.so
         MODULE_PATH            = /usr/lib/x86_64-linux-gnu/pkcs11/yubihsm_pkcs11.so
         PIN                    = __PIN__
         init                   = 0
       engine_usage: 'ALWAYS'
       key_store: ENGINE
       shell: /usr/bin/openssl
       randfile: /var/openxpki/rand
       wrapper: ''
       secret: signer

The linked secret is only used to get access to the HSM.
The secret used to unlock the HSM can be configured normally.
For the YubiHSM2 for example a secret group that uses the authentication key
*0x0001* with the password *password* would be the following::

     secret:
       signer:
         label: YubiHSM password
         method: literal
         value: 0001password
         cache: daemon

**Note:** To be able to use the YubiHSM2 with OpenSSL, two environment variables has to be set (``YUBIHSM_PKCS11_CONF`` and ``YUBIHSM_PKCS11_MODULE``).
If those environment variables are set when the server is started, the OpenXPKI
process inherits these values.

Secret Groups
^^^^^^^^^^^^^

A secret group maintains the password cache for your keys and PINs.
You need to setup at least one secret group for each realm. The most
common version is the plain password::

    secret:
      default:
        label: One Piece Password
        method: plain
        cache: daemon


This tells the OpenXPKI daemon to ask for the default only once and then
store it "forever". If you want to have the secret cleared at the end of
the session, set *cache: session*.

To increase the security of your key material, you can configure secret
splitting by dividing the PIN entry into n components that are simply
concatenated. ::

    secret:
      ngkey:
        label: Split secret Password
        method: plain
        total_shares: 3
        cache: daemon

If you have a good reason to put your password into the configuration,
use the *literal* type::

    secret:
      insecure:
        label: A useless Password
        method: literal
        value: my_not_so_secret_password
        cache: daemon

You can also use the secret groups for other purposes, in this case you
need to add "export: 1" to the group. This allows you to use the get_secret
method of the TokenManager (OpenXPKI::Crypto::TokenManager) to retrieve the
plain value of the secret.


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
        starttls: 0
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
        dir:   /home/pkiadm/democa/email/

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
that belong to a certain thread go to the same recipients using the same subject
prefix. **Note, that settings to those options in later messages are ignored!**

**recipient information**

The primary recipient and a from address are mandatory:

- to: The primary recipient, single value, parsed using TT
- from: single value, NOT parsed

Additional recipients and a seperate Reply-To header are optional:

- cc: comma seperated list, parsed using TT
- reply: single value, NOT parsed

All values need to be rfc822 compliant full addresses.

**composing the subject**

The subject is parsed using TT. If you have specified a prefix, it is automatically prepended.

**composing the message body**

The body of a message is read from the filename specified by *template*, where the
suffix '.txt' is always apppended. So the full path for the message at
``messages.csr_created.user`` is */home/pkiadm/democa/email/csr_created_user.txt*.

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
e.g. */home/pkiadm/democa/email/images/head.png*. The files must end on
gif/png/jpg as the suffix is used to detect the correct image type.

To test your notification config, you can trigger a test message via the
command line interface::

    openxpkicli send_notification --arg message=testmail --param notify_to=me@company.org


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
        dir:   /home/pkiadm/democa/rt/

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

For *correspond* the result is also mailed to the ticket recipients (this
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



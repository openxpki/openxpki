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

**x509 client-based authentication**

The ClientX509 handler uses the certificate information provided by the connecting client to perform authorization only. It's left to the client to perform the authentication step and ensure that the passed cert is controlled by the user. The handler checks the validity of the certificate and uses a connector to assign the user a role. This is a typical setup when you use Apache SSL with mutual authentication. ::

    Certificate:
        type: ClientX509
        label: Certificate
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_CERTIFICATE_WEBSERVER
        role: 
            default: ''
            handler@: auth.roledb
            argument: dn
            
The role assignment is done by querying the connector specified by *handler* using the certificates component *argument*. Possible arguments are "cn", "subject" and "serial". The value given by *default* is assigned if no match is found by the handler. If you do not specify a handler but a default role, you get a static role assignment for any matching certifiacate.
        
**x509 Authentication**

Perform x509 based authentication with challenge/response. The  ::

    Signature:
        type: X509
        label: Signature
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_SIGNATURE
        challenge_length: 256
        role: 
            default: ''
            handler@: auth.roledb
            argument: dn
        # define your trust anchors here
        realm:
        - my_client_auth_realm
        cacert:
        - cert_identifier of external ca cert

The *challenge_length* determines the size of the challenge in bytes. There are two alternative to specify which certificates are accpeted:

#. If the certificates originate from the OpenXPKI instance itself, list the realms which issue them below *realm*.
#. If you have certificates from an external ca, import the ca certificate and put its certificate identifier below *cacert*. Both lists can be combined and accept any number of items.

The settings for *role* are the same as for the x509 client handler.

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

The passwords are hashed, the used hash algorithm is given as prefix inside the curly brackets. You should use only *SSHA* which is "salted sha1". For compatibility we support plain sha1, md5, smd5 (salted md5) and crypt. You can created the salted passwords using the openxpkiadm CLI tool.

If you plan to use static passwords for a larger amount of users, you should consider to use a connector instead::

    Password:
        type: Password
        label: User Password
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_PASSWORD
        user@: auth.userdb        
        
    userdb:
        class: Connector::Proxy::YAML
        LOCATION: /home/pkiadm/userdb.yaml       

The user file has the same structure then the *user* section above.

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


The given example shows everything but any context items that begin with "encrypted_". The filters are additive, so a key must match the show expression but must not match the hide expression to show up. *Note*: No setting or an empty string for *show* results in no filtering! To hide the whole context set a wildcard ".*" for *hide*.


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

If your openssl setup supports the predefined naming scheme, you can also use path expansion with inheritance. Set the *key* value to a directory and name your keys "<aliasname>.pem". The example above will then look like::

    token:  
        default:
            backend: OpenXPKI::Crypto::Backend::OpenSSL
            key: /etc/openxpki/ssl/ca-one/
            ......
            secret: default
        
        server-ca-1:
            inherit: default
            secret: gen1key
    
        server-ca-2:
            inherit: default

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

The following code shows the full set of supported extensions, you can leave out what you do not need::

    extensions:
        authority_info_access:
            critical: 0
            ca_issuers: http://myca.mycompany.com/[% CAALIAS %]/cacert.pem
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

        
Workflow
--------

The definition of the workflows is still in the older xml format, already used in older OpenXPKI releases but its management is included into the connector now. The XML files are located in the folder named *_workflow* (**note the underscore!**) in the top level direcotry of the realm. If you are upgrading from an older installation, you can just move your old workflow*.xml files here *and* add an outer "openxpki" tag to the *workflow.xml* file.



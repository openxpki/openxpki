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

The ClientX509 handler uses the certificate information provided by the connecting client to perform authorization only. It's left to the client to perform the authentication step and ensure that the passed cert is controlled by the user. This is a typical setup when you use Apache SSL with mutual authentication. ::

    Certificate:
        type: ClientX509
        label: Certificate
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_CERTIFICATE_WEBSERVER


**x509 Authentication**

Perform x509 based authentication with challenge/response. ::

    Signature:
        type: X509
        label: Signature
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_SIGNATURE
        challenge_length: 256
        # define your trust anchors here
        realm:
        - my_client_auth_realm
        cacert:
        - cert_identifier of external ca cert

The *challenge_length* determines the size of the challenge in bytes. There are two alternative to specify which certificates are accpeted:

#. If the certificates originate from the OpenXPKI instance itself, list the realms which issue them below *realm*.
#. If you have certificates from an external ca, import the ca certificate and put its certificate identifier below *cacert*. Both lists can be combined and accept any number of items.

**password database handler**

The password database handler allows to specify user/password/role pairs directly inside the configuration. ::

    Password:
        type: Password
        label: User Password
        description: I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_PASSWORD
        # howto generate sha1 passphrases? 
        # echo -n root | openssl sha1 -binary | openssl base64
        user:
          - name: John Doe
            digest: "{SSHA}TZXM/aqflDDQAmSWVxSDVWnH+NhxNU5w"
            role: User
          - name: root
            digest: "{SSHA}+u48F1BajP3ycfY/azvTBqprsStuUnhM"
            role: CA Operator
          - name: raop
            digest: "{SSHA}ejZpY22dFwjVI48z14y2jYuToPRjOXRP"
            role: RA Operator

The passwords are hashed, the used hash algorithm is given as prefix inside the curly brackets. You should use only *SSHA* which is "salted sha1". For compatibility we support plain sha1, md5, smd5 (salted md5) and crypt.

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



Crypto layer
------------

Profiles
--------
    
Publishing
----------
        
Workflow
--------
    

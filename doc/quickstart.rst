.. _quickstart:

Quickstart guide
================

Debian/Ubuntu Development Builds
---------------------------------

**Packages are for 64bit systems (arch amd64), make sure that the en_US.utf8 locale is installed as the mason client will crash otherwise!**

Starting with our preview release 0.11.3 we will publish packages mainly for debian 7 (wheezy) and Ubuntu 12.04.  
You can find them on our package mirror at http://packages.openxpki.org/. 

Packages are build from the development head, versioned packages are build from the release branch. 
The preview builds "should work" but some stuff might need a bit of manual tweaking.

Add the repository to your source list (wheezy)::

    echo "deb http://packages.openxpki.org/debian/ wheezy/release/" > /etc/apt/sources.list.d/openxpki.list
    aptitude update   
    
or ubuntu::

    echo "deb http://packages.openxpki.org/ubuntu/ precise/release/" > /etc/apt/sources.list.d/openxpki.list
    aptitude update

As the init script uses mysql as default, but does not force it as a dependancy, it is crucial that you have the mysql server installed before you pull the OpenXPKI package::

    aptitude install mysql-server
    aptitude install libopenxpki-perl

If the install was successful, you should see the result of the initial config import at the bottom of your install log (the hash value might vary)::

    Current Tree Version: 64f82c3479f5773536f9ff7d37da366ea49abae9

Now, create the database user::

    CREATE database openxpki;
    CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
    GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
    flush privileges;

It is now time to init the server::

    openxpkiadm loadcfg
    openxpkiadm initdb

Setup base certificates
^^^^^^^^^^^^^^^^^^^^^^^

The debian package comes with a shell script ``sampleconfig.sh`` that does all the work for you 
(look in /usr/share/doc/libopenxpki-perl/examples/). The script will create a two stage ca with 
a root ca certificate and below your issuing ca and certs for SCEP and the internal datasafe.

The sample script proves certs for a quickstart but should never be used for production systems 
(it has the fixed passphrase *root* for all keys ;) and no policy/crl, etc config ).
 
Here is what you need to do:

#. Create a key/certificate as signer certificate (ca = true)
#. Create a key/certificate for the internal datavault (ca = false, can be below the ca but can also be self-signed).
#. Create a key/certificate for the scep service (ca = false, can be below the ca but can also be self-signed or from other ca).

Move the key files to /etc/openxpki/ssl/ca-one/ and name them ca-one-signer-1.pem, ca-one-vault-1.pem, ca-one-scep-1.pem. 
The key files must be readable by the openxpki user, so we recommend to make them owned by the openxpki user with mode 0400. 

Now import the certificates to the database, the realm/issuer line is required if the certificate is not self signed.

:: 
    
    openxpkiadm certificate import  --file ca-root-1.crt 
        
    openxpkiadm certificate import  --file ca-one-signer-1.crt \
        --realm ca-one --issuer `openxpkiadm certificate id --file ca-root-1.crt`
        
    openxpkiadm certificate import  --file ca-one-vault-1.crt \
        --realm ca-one --issuer `openxpkiadm certificate id --file ca-root-1.crt`
           
    openxpkiadm certificate import  --file ca-one-scep-1.crt \
        --realm ca-one --issuer `openxpkiadm certificate id --file ca-root-1.crt`     
        
To link these certificates to the internal tokens, you need to set a so called alias::         
     
    openxpkiadm alias --realm ca-one --token certsign \
        --identifier `openxpkiadm certificate id --file ca-one-signer-1.crt`
        
    openxpkiadm alias --realm ca-one --token datasafe \
        --identifier `openxpkiadm certificate id --file ca-one-vault-1.crt`  \        

    openxpkiadm alias --realm ca-one --token scep \
        --identifier `openxpkiadm certificate id --file ca-one-scep-1.crt`  \
        --realm ca-one --issuer `openxpkiadm certificate id --file ca-root-1.crt`

If the import went smooth, you should see something like this (ids and times will vary)::

    $ openxpkiadm alias --realm ca-one
    
    scep (ca-one-scep):
      Alias     : ca-one-scep-1
      Identifier: Xol0OArASuzS4bYiROxLvGKdl_4
      NotBefore : 2013-09-20 08:41:05
      NotAfter  : 2014-09-20 08:41:05
    
    datasafe (ca-one-vault):
      Alias     : ca-one-vault-1
      Identifier: ZnUjwmB4gqOtZagj2iSc8hLqJis
      NotBefore : 2013-09-20 08:41:05
      NotAfter  : 2014-09-20 08:41:05
    
    certsign (ca-one-signer):
      Alias     : ca-one-signer-1
      Identifier: She8R9sivQf_F7Rql7_Qph2Ec0U
      NotBefore : 2013-09-20 08:41:04
      NotAfter  : 2014-09-20 08:41:04
    
    current root ca:
      Alias     : root-1
      Identifier: eGDjexhUDL60vzl4Se-DlIlhpUA
      NotBefore : 2013-09-20 08:41:03
      NotAfter  : 2018-08-25 08:41:03
    
    upcoming root ca:
      not set
        
    
Now it is time to see if anything is fine::

    $ openxpkictl start
    
    Starting OpenXPKI...
    OpenXPKI Server is running and accepting requests.
    DONE.
    
In the process list, you should see two process running::

    14302 ?        S      0:00 openxpki watchdog ( main )
    14303 ?        S      0:00 openxpki server ( main )    

If this is not the case, check */var/openxpki/stderr.log*. 

Adding the Webclient
^^^^^^^^^^^^^^^^^^^^

The webclient uses the Mason toolkit and mod_perl, get the package::

    aptitude install libopenxpki-client-html-mason-perl
    
If the install is done, point your webbrowser to *http://yourhost/openxpki/*. You should see the main authentication page. If you get an internal server error, make sure you have the en_US.utf8 locale installed (*locale -a | grep en_US*)!

The test setup uses a fully insecure password handler *External Dynamic* - just enter any username and give one of

* User
* RA Operator
* CA Operator

as the password. You will be logged in with the username and the "password" is used as the default role (pay attention to the captial letters, it's case SenSitIve!).

Testdrive
^^^^^^^^^

#. Login as User (Username: bob, Password: User)
#. Go to "Request", select "Certificate Signing Request"
#. Follow the white rabbit
#. Logout and re-login as RA Operator (Username: raop, Password: RA Operator)  
#. Go to "Approval", select "Pending Signing Requests"
#. Select your Request, use the button on the top to approve the request
#. After some seconds, your first certificate is ready :)
#. You can now login with your username and fetch the certificate 

Enabling the SCEP service
^^^^^^^^^^^^^^^^^^^^^^^^^

The SCEP logic is already included in the core distribution. The package installs
a wrapper script into /usr/lib/cgi-bin/ and creates a suitable alias in the apache
config redirecting all requests to `http://host/scep/<any value>` to the wrapper. 
A default config is placed at /etc/openxpki/scep/default.conf. For a testdrive, 
there is no need for any configuration, just call ``http://host/scep/scep``.

The system supports getcacert, getcert, getcacaps, getnextca and enroll/renew - the 
shipped workflow is configured to allow enrollment with password or signer on behalf.
The password has to be set in ``scep.yaml``, the default is 'SecretChallenge'.
For signing on behalf, use the UI to create a certificate with the 'SCEP Client'
profile - there is no password necessary. Advanced configuration is described in the 
scep workflow section. 

The best way for testing the service is the sscep command line tool (available at
e.g. https://github.com/certnanny/sscep).  

Check if the service is working properly at all::

    mkdir tmp
    ./sscep getca -c tmp/cacert -u http://yourhost/scep/scep
    
Should show and download a list of the root certificates to the tmp folder.

To test an enrollment::

    openssl req -new -keyout tmp/scep-test.key -out tmp/scep-test.csr -newkey rsa:2048 -nodes
    ./sscep enroll -u http://yourhost/scep/scep \
        -k tmp/scep-test.key -r tmp/scep-test.csr \
        -c tmp/cacert-0 \
        -l tmp/scep-test.crt \ 
        -t 10 -n 1

Make sure you set the challenge password when prompted (default: 'SecretChallenge').
On current desktop hardware the issue workflow will take approx. 15 seconds to 
finish and you should end up with a certificate matching your request in the tmp 
folder.      

Starting from scratch
---------------------

If you don't use debian or just like the hard way you can of course start from out github repo.
The debian build file are the current "authorative source" regarding to dependencies, etc. so 
the dependencies in the Makefile might not be fully sufficient.
  
Clone the git repository to your box::

    cd /usr/local/src/
    git clone git://github.com/openxpki/openxpki.git
    
    cd openxpki/core/server
    perl Makefile.PL
    make

Make test requires a running mysql server, so configure your database user first as described in the debian install above.
       
Now test and install, if you want to change the install location, see perldoc ExtUtils::MakeMaker how to change prefixes.          
    
    make test    
    make install

You should now have the necessary perl library files and the helper scripts in place. Now its time to create a user and group for the daemon, the default is *openxpki*. 
 
Setup necessary filesystem ressources::

    mkdir -p -m 0775 /var/openxpki/session 
    chown -R root:openxpki /var/openxpki/
    
    mkdir -p /etc/openxpki/config.d/
    
    mkdir -p -m 0700 /etc/openxpki/ssl/ca-one/
    chown -R openxpki:root /etc/openxpki/ssl/ca-one/

...and copy an initial configuration from the examples directory::
    
    cp -r /usr/local/src/openxpki/core/config/log.conf /etc/openxpki/
    cp -r /usr/local/src/openxpki/core/config/basic/* /etc/openxpki/config.d/
     
Continue with creating your certificates as mentioned above and follow the rest of the guide. 

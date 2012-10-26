.. _quickstart:

Quickstart guide
================

**Use a debian squeeze US install or install en_US.utf8 locale as the mason client will crash otherwise!**

Debian Development Builds
--------------------------

We publish build packages from the development head, it "should work" but some stuff needs a bit of manual tweaking.

Add our deb-repository to your source list::

    echo "deb http://packages.openxpki.org/debian/ squeeze/binary/" > /etc/apt/sources.list.d/openxpki.list

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

Create your ca certificate:: 
    
    cd /etc/openxpki/ssl/ca-one/
    openssl req -newkey rsa:2048 -new -days 1830 -x509 -keyout ca-one-signer-1.pem -out ca-one-signer-1.crt  -passout pass:root
    
Create a key for the internal datasafe (not exposed externally)::    

    openssl req -newkey rsa:2048 -new -days 400 -x509 -keyout ca-one-vault-1.pem -out ca-one-vault-1.crt -passout pass:root

**Note:** The sample config uses the fixed passphrase *root* as password for both keys, please change this for your production deployment!

The following creates the initial configuration repository, inits the database schema and imports the certificates into the database:: 
       
    openxpkiadm loadcfg
    openxpkiadm initdb
    
    openxpkiadm certificate import  --file /etc/openxpki/ssl/ca-one/ca-one-signer-1.crt 
    openxpkiadm alias --realm ca-one --token certsign --identifier <identifier from import>
    
    openxpkiadm certificate import  --file /etc/openxpki/ssl/ca-one/ca-one-vault-1.crt 
    openxpkiadm alias --realm ca-one --token datasafe --identifier <identifier from import>
    
Now it is time to see if anything is fine::

    openxpkictl start
    
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

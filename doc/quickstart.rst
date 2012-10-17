.. _quickstart:

Quickstart guide
================

**We currently only have a nice server but no client packages - so setting up a server is a bit useless at the moment if you are not a developer**

Debian Development Builds
--------------------------

We publish build packages from the development head, but the packages are a bit incomplete at the moment, so you need to do some manual work on top.

Add our deb-repository to your source list:
deb http://packages.openxpki.org/debian/ squeeze/binary/

Install some useful packages and pull the OpenXPKI code::

    aptitude install mysql-server git rsync
    aptitude install libopenxpki-perl

Create a database user::

    CREATE database openxpki;
    CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
    GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
    flush privileges;

Checkout the git repository to a temp location and copy deployment stuff::

    cd /tmp
    git clone git://github.com/openxpki/openxpki.git
    mkdir /etc/openxpki
    cp -r openxpki/trunk/deployment/etc/config.d /etc/openxpki
    cp openxpki/trunk/deployment/etc/log.conf /etc/openxpki
    
    cp openxpki/trunk/deployment/bin/openxpkiadm /usr/bin/openxpkiadm
    cp openxpki/trunk/deployment/bin/openxpkictl /usr/bin/openxpkictl
    

Setup necessary filesystem ressources::

    mkdir -p -m 0775 /var/openxpki/session 
    chown -R root:openxpki /var/openxpki/
    
    mkdir -p /etc/openxpki/config.d/realm/
    cp /etc/openxpki/config.d/realm.tpl/  /etc/openxpki/config.d/realm/ca-one
    
    mkdir -p /etc/openxpki/ssl/ca-one/
    cd /etc/openxpki/ssl/ca-one/

Create your ca certificate:: 
    
    openssl req -newkey rsa:2048 -new -days 365 -x509 -keyout ca-one-signer-1.pem -out ca-one-signer-1.crt
    
Create a key for the internal datasafe (not exposed externally)::    

    openssl req -newkey rsa:2048 -new -days 365 -x509 -keyout ca-one-vault-1.pem -out ca-one-vault-1.crt

**Note:** The sample config uses the fixed passphrase *root* as password for both keys, so for testing set it accordingly.

The following creates the initial configuration repository, inits the database schema and imports the certificates into the database:: 
    
    openxpkiadm loadcfg
    openxpkiadm initdb
    
    openxpkiadm certificate import  --file ssl/ca-one/ca-one-signer-1.crt 
    openxpkiadm alias --realm ca-one --token certsign --identifier <identifier from import>
    
    openxpkiadm certificate import  --file ssl/ca-one/ca-one-vault-1.crt 
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



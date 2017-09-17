.. _quickstart:

Quickstart guide
================

Vagrant
-------

We have a vagrant setup for debian jessie and ubuntu trusty. If you have vagrant you can just
checkout the git repo, go to vagrant/debian and run "vagrant up test". Provisioning takes some
minutes and will give you a ready to run OXI install available at http://localhost:8080/openxpki/.

Debian/Ubuntu Builds
----------------------

**Packages are for 64bit systems (arch amd64), make sure that the en_US.utf8 locale is installed as the translation stuff will crash otherwise!**

Start with a debian minimal install, we recommend to add "SSH Server" and "Web Server" in the package selection menu, as this will speed up the install later::

Current release is |version| which is out for debian jessie and ubuntu trusty (14.04 LTS) on the package mirror at http://packages.openxpki.org/.

Add the repository to your source list (jessie)::

    echo "deb http://packages.openxpki.org/debian/ jessie release" > /etc/apt/sources.list.d/openxpki.list
    aptitude update

or ubuntu *trusty (14.04 LTS)* (those *DONT* work on recent Xenial 16.04!) ::

    echo "deb http://packages.openxpki.org/ubuntu/ dists/trusty/release/binary-amd64/" > /etc/apt/sources.list.d/openxpki.list
    aptitude update

To avoid an "untrusted package" warning, you should add our package signing key (works only on debian yet)::

    wget https://packages.openxpki.org/debian/Release.key -O - | apt-key add -

The https connection is protected by a Let's Encrypt certificate but if you want to validate the key on your own, the fingerprint is::

    gpg --print-md sha256 Release.key 
    Release.key: 78FE9779 A10D64CA 3CBB8D4C CE1DE44C 1AC69A93 FF2EFCF9 3AADBEC9 D3378F7B

As the init script uses mysql as default, but does not force it as a dependency, it is crucial that you have the mysql server and the perl mysql binding installed before you pull the OpenXPKI package::

    aptitude install mysql-server libdbd-mysql-perl

We strongly recommend to use a fastcgi module as it speeds up the UI, we recommend mod_fcgid as it is in the official main repository (mod_fastcgi will also work but is only available in the non-free repo)::

    aptitude install libapache2-mod-fcgid

Note, fastcgi module should be enabled explicitly, otherwise, .fcgi file will be treated as plain text (this is usually done by the installer already)::

    a2enmod fcgid

Some people reported that a2enmod is not available on their system, in this case try to install the apache2.2-common package.

*Ubuntu only*: Some of the provided perl packages are too old, you need to install recent versions from our package server by hand! The packages signatures are not working on ubuntu, so you need to confirm that you want to install the "untrusted packages"::

    aptitude install libcgi-perl libmodule-load-perl

Now install the OpenXPKI core package and the translation package::

    aptitude install libopenxpki-perl openxpki-i18n

You should now restart the apache server to activate the new config::

    service apache2 restart

use the openxpkiadm command to verify if the system was installed correctly::

    openxpkiadm version
    Version (core): 1.17.4

Now, create an empty database and assign a database user::

    CREATE DATABASE openxpki CHARSET utf8;
    CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
    GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
    flush privileges;

...and put the used credentials into /etc/openxpki/config.d/system/database.yaml::

    main:
       debug: 0
       type: MySQL
       name: openxpki
       host: localhost
       port: 3306
       user: openxpki
       passwd: openxpki


Starting with v1.13, the "initdb" command is deprecated, please create
the empty database schema from the provided schema file (currently only
available for mysql).

Example call when debian packages are installed::

    zcat /usr/share/doc/libopenxpki-perl/examples/schema-mysql.sql.gz | \
        mysql -u root -p openxpki

If you do not use debian packages, you can get a copy from the config/sql/
folder of the repository.


Setup base certificates
^^^^^^^^^^^^^^^^^^^^^^^

The debian package comes with a shell script ``sampleconfig.sh`` that does all the work for you
(look in /usr/share/doc/libopenxpki-perl/examples/). The script will create a two stage ca with
a root ca certificate and below your issuing ca and certs for SCEP and the internal datasafe.

The sample script provides certs for a quickstart but should never be used for production systems
(it has the fixed passphrase *root* for all keys ;) and no policy/crl, etc config ).

Here is what you need to do if you *dont* use the sampleconfig script.

#. Create a key/certificate as signer certificate (ca = true)
#. Create a key/certificate for the internal datavault (ca = false, can be below the ca but can also be self-signed).
#. Create a key/certificate for the scep service (ca = false, can be below the ca but can also be self-signed or from other ca).

Move the key files to /etc/openxpki/ssl/ca-one/ and name them ca-one-signer-1.pem, ca-one-vault-1.pem, ca-one-scep-1.pem.
The key files must be readable by the openxpki user, so we recommend to make them owned by the openxpki user with mode 0400.

Now import the certificates to the database. The signer token is used exclusive in the current realm,
so we can use a shortcut and import and reference it with one command.

::

    openxpkiadm certificate import  --file ca-root-1.crt

    openxpkiadm certificate import  --file ca-one-signer-1.crt \
        --realm ca-one --token certsign

As we might want to reuse SCEP and Vault token across the realms, we import them in to the global
namespace and just create an alias in the current realm::

    openxpkiadm certificate import  --file ca-one-vault-1.crt
    openxpkiadm certificate import  --file ca-one-scep-1.crt

    openxpkiadm alias --realm ca-one --token datasafe \
        --identifier `openxpkiadm certificate id --file ca-one-vault-1.crt`

    openxpkiadm alias --realm ca-one --token scep \
        --identifier `openxpkiadm certificate id --file ca-one-scep-1.crt`


If the import went smooth, you should see something like this (ids and times will vary)::

    $ openxpkiadm alias --realm ca-one

    === functional token ===
    ca-one-scep (scep):
    Alias     : ca-one-scep-1
    Identifier: YsBNZ7JYTbx89F_-Z4jn_RPFFWo
    NotBefore : 2015-01-30 20:44:40
    NotAfter  : 2016-01-30 20:44:40

    ca-one-vault (datasafe):
    Alias     : ca-one-vault-1
    Identifier: lZILS1l6Km5aIGS6pA7P7azAJic
    NotBefore : 2015-01-30 20:44:40
    NotAfter  : 2016-01-30 20:44:40

    ca-one-signer (certsign):
    Alias     : ca-one-signer-1
    Identifier: Sw_IY7AdoGUp28F_cFEdhbtI9pE
    NotBefore : 2015-01-30 20:44:40
    NotAfter  : 2018-01-29 20:44:40

    === root ca ===
    current root ca:
    Alias     : root-1
    Identifier: fVrqJAlpotPaisOAsnxa9cglXCc
    NotBefore : 2015-01-30 20:44:39
    NotAfter  : 2020-01-30 20:44:39

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

If this is not the case, check */var/log/openxpki/stderr.log*. 

Adding the Webclient
^^^^^^^^^^^^^^^^^^^^

The new webclient is included in the core packages now. Just open your browser and navigate to *http://yourhost/openxpki/*. You should see the main authentication page. If you get an internal server error, make sure you have the en_US.utf8 locale installed (*locale -a | grep en_US*)!

You can log in as user with any username/password combination, the operator login has two preconfigured operator accounts raop and raop2 with password openxpki.

If you only get the "Open Source Trustcenter" banner without a login prompt,
check that fcgid is enabled as described above with 
(*a2enmod fcgid; service apache2 restart).

Testdrive
^^^^^^^^^

#. Login as User (Username: bob, Password: <any>)
#. Go to "Request", select "Request new certificate"
#. Complete the pages until you get to the status "PENDING" (gray box on the right)
#. Logout and re-login as RA Operator (Username: raop, Password: openxpki )
#. Select "Home / My tasks", there should be a table with one request pending
#. Select your Request by clicking the line, change the request or use the "approve" button
#. After some seconds, your first certificate is ready :)
#. You can download the certificate by clicking on the link in the first row field "certificate"
#. You can now login with your username and fetch the certificate

Enabling the SCEP service
^^^^^^^^^^^^^^^^^^^^^^^^^

**Note: You need to manually install the openca-tools package which is available from
our package server in order to use the scep service.**

The SCEP logic is already included in the core distribution. The package installs
a wrapper script into /usr/lib/cgi-bin/ and creates a suitable alias in the apache
config redirecting all requests to ``http://host/scep/<any value>`` to the wrapper.
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

Support for Java Keystore
^^^^^^^^^^^^^^^^^^^^^^^^^

OpenXPKI can assemble server generated keys into java keystores for
immediate use with java based applications like tomcat. This requires
a recent version of java ``keytool`` installed. On debian, this is
provided by the package ``openjdk-7-jre``. Note: You can set the
location of the keytool binary in ``system.crypto.token.javajks``, the
default is /usr/bin/keytool.



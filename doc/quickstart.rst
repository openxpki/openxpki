.. _quickstart:

Quickstart guide
================

OpenXPKI is an easy-to-deploy and easy-to-use RA/CA software that makes
handling of certificates easy but nevertheless you should **really**
have some basic knownledge on what a PKI is. If you just want to see
"OpenXPKI in action" for a first impression of the tool, use the
public demo at https://demo.openxpki.org.

Support
-------

If you need help, please use the mailing list and do **NOT** open items
in the issue tracker on github. For details and additional support options
have a look at http://www.openxpki.org/support.html.

Vagrant
-------

We have a vagrant setup for debian buster. If you have vagrant you can just
checkout the git repo, go to vagrant/debian and run "vagrant up test". Provisioning takes some
minutes and will give you a ready to run OXI install available at https://localhost:8443/openxpki/.

Docker
------

We also provide a docker image based on the debian packages as well as a
docker-compose file, see https://github.com/openxpki/openxpki-docker.
**Please read the hints in the README if you try this on Windows!**


Configuration
-------------

The debian package come with a sample configuration, for a production setup
we recommend to remove the `/etc/openxpki` folder created by the package and
replace it with a checkout of the `community` branch of the configuration
repository available at https://github.com/openxpki/openxpki-config. Please
also have a look at the [QUICKSTART.md document](https://github.com/openxpki/openxpki-config/blob/community/QUICKSTART.md)
which has some more detailed instructions how to setup the system.

**Note**: The configuration is (usually) backward compatible but most releases
introduce new components and new configuration that can not be used with
old releases. Make sure your code version is recent enough to run the config!
Starting with v3.12, the code checks its compatibility with the config itself
via the `system.version.depend` node. We recommend to keep and maintain this
in your config!


Debian Builds
-------------

New users should use the v3 release branch which is available for Debian 10 (Buster), for
those running a v2 version we still maintain security and major bug fixes for the old release.

**Packages are for Debian 10 (Buster) / 64bit (arch amd64). The en_US.utf8 locale must be
installed as the translation system will crash otherwise! The packages do NOT work
on Ubuntu or 32bit systems. Packages for SLES/CentOS/RHEL/Ubuntu are available
via subscription**

Start with a debian minimal install, we recommend to add "SSH Server" and "Web Server" in the package selection menu, as this will speed up the install later.

To avoid an "untrusted package" warning, you should add our package signing key (you might need to install gpg before)::

    wget https://packages.openxpki.org/v3/debian/Release.key -O - | apt-key add -

The https connection is protected by a Let's Encrypt certificate but if you want to validate the key on your own, the fingerprint is::

    gpg --print-md sha256 Release.key
    Release.key: 9B156AD0 F0E6A6C7 86FABE7A D8363C4E 1611A2BE 2B251336 01D1CDB4 6C24BEF3

Add the repository to your source list (buster)::

    echo "deb http://packages.openxpki.org/v3/debian/ buster release" > /etc/apt/sources.list.d/openxpki.list
    apt update

Please do not disable the installation of "recommend" packages as this will very likely leave you with an unusable system.

As OpenXPKI can run with different RDBMS, the package does not list any of them as dependency. You therefore need to install the required perl bindings and server software yourself::

    apt install default-mysql-server libdbd-mysql-perl

We strongly recommend to use a fastcgi module as it speeds up the UI, we recommend mod_fcgid as it is in the official main repository (mod_fastcgi will also work but is only available in the non-free repo)::

    apt install apache2 libapache2-mod-fcgid

Note, fastcgi module should be enabled explicitly, otherwise, .fcgi file will be treated as plain text (this is usually done by the installer already)::

    a2enmod fcgid

Now install the OpenXPKI core package, session driver and the translation package::

    apt install libopenxpki-perl openxpki-cgi-session-driver openxpki-i18n

use the openxpkiadm command to verify if the system was installed correctly::

    openxpkiadm version
    Version (core): 3.10.0

Now, create an empty database and assign a database user::

    CREATE DATABASE openxpki CHARSET utf8;
    CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
    GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
    flush privileges;

...and put the used credentials into /etc/openxpki/config.d/system/database.yaml::

    main:
       debug: 0
       type: MariaDB
       name: openxpki
       host: localhost
       port: 3306
       user: openxpki
       passwd: openxpki


Starting with the v3.8 release we added a MariaDB driver that makes use of MariaDB internal
sequences instead of the emulation code and we recommend any new installations to use it!

Please create the empty database schema from the provided schema file. mariadb/mysql and
postgresql should work out of the box, the oracle schema is good for testing but needs some
extra indices to perform properly.

Example call when debian packages >= v3.8 are installed::

    zcat /usr/share/doc/libopenxpki-perl/examples/schema-mariadb.sql.gz | \
         mysql -u root --password --database  openxpki

If you do not use debian packages, you can get a copy from ``contrib/sql/`` in the
config repository https://github.com/openxpki/openxpki-config.


Setup base certificates
^^^^^^^^^^^^^^^^^^^^^^^

The debian package comes with a shell script ``sampleconfig.sh`` that does all the work for you
(look in /usr/share/doc/libopenxpki-perl/examples/). The script will create a two stage ca with
a root ca certificate and below your issuing ca and certs for SCEP and the internal datasafe.

This script provides a quickstart but should **never be used for production systems**
(it has the fixed passphrase *root* for all keys ;) and no policy/crl, etc config ).

Here is what you need to do if you *dont* use the sampleconfig script:.:

#. Create a key/certificate as signer certificate (your CA certificate, *ca = true*)
#. Create a key/certificate for the internal datavault (ca = false, can be below the ca but can also be self-signed).
#. Create a key/certificate for the scep service (ca = false, can be below the ca but can also be self-signed or from other ca).

OpenXPKI supports NIST and Brainpool ECC curves (as supported by openssl) for the CA certificates, as the Datavault
certificate is used for data encryption it **MUST** use an RSA key! You should also remove the `democa` realm and
create a realm with a proper name (see [reference/configuration/introduction.html#main-configuration]).

**Starting with release 3.6 the default config uses the database to store the issuing ca and SCEP tokens -
if you upgrade from an older config version check the new settings in systems/crypto.yaml.**

Import Root CA
##############

OpenXPKI needs to be able to build the full chain for any certificate so we need
to import the Root CA(s) first::

    $ openxpkiadm certificate import --file root.crt

Create DataVault Token
######################

The DataVault is a self-signed certificate using an RSA key, see #2 above.

Copy the DataVault key file to /etc/openxpki/local/keys/vault-1.pem, it should have 0400
permission owned by the openxpki user.

Now import the certificate::

    $ openxpkiadm certificate import --file vault.crt

    Starting import
    Successfully imported certificate into database:
      Subject:    CN=Internal DataVault
      Issuer:     CN=Internal DataVault
      Identifier: YsyZ4eCgzHQN607WBIcLTxMjYLI
      Realm:      none

Register it as datasafe token for the `democa` realm - you need to run this
command for each realm::

    $ openxpkiadm alias --realm democa --token datasafe --file vault.crt

    Successfully created alias in realm democa:
      Alias     : vault-1
      Identifier: YsyZ4eCgzHQN607WBIcLTxMjYLI
      NotBefore : 2020-07-06 18:54:43
      NotAfter  : 2030-07-09 18:54:43

Now its time to start the OpenXPKI Server::

    $ openxpkictl start

    Starting OpenXPKI...
    OpenXPKI Server is running and accepting requests.
    DONE.

In the process list, you should see two process running::

    14302 ?        S      0:00 openxpki watchdog ( main )
    14303 ?        S      0:00 openxpki server ( main )

If this is not the case, check */var/log/openxpki/stderr.log*.

You should check now if your DataVault token is working::

    $ openxpkicli  get_token_info --arg alias=vault-1
    {
        "key_name" : "/etc/openxpki/local/keys/vault-1.pem",
        "key_secret" : 1,
        "key_store" : "OPENXPKI",
        "key_usable" : 1
    }

If you do not see `"key_usable": 1` your token is not working! Check the
permissions of the file (and the folders) and if the key is password
protected if you have the right secret set in your crypto.yaml!


Create Issuing CA Token
#######################

The `openxpkiadm alias` command offers a shortcut to import the certificate,
register the token and store the private key. Repeat this step for all issuer
tokens in all realms. The system will assign the next available generation
number and create all required internal links. In case you choose the filesystem
as key storage the command will write the key files to the intended location but
requires that the parent folder exist (`/etc/openxpki/local/keys/<realm>`)::

    openxpkiadm alias --realm democa --token certsign \
        --file democa-signer.crt --key democa-signer.pem

Perform the same for the SCEP token::

    openxpkiadm alias --realm democa --token scep \
        --file scep.crt --key scep.pem

**Note**: Each realm needs his own SCEP token so you need to run this command
any realm that provides an SCEP service. It is possible to use the same SCEP
token in multiple realms.

If the import went smooth, you should see something like this (ids and times will vary)::

    $ openxpkiadm alias --realm democa

    === functional token ===
    scep (scep):
    Alias     : scep-1
    Identifier: YsBNZ7JYTbx89F_-Z4jn_RPFFWo
    NotBefore : 2015-01-30 20:44:40
    NotAfter  : 2016-01-30 20:44:40

    vault (datasafe):
    Alias     : vault-1
    Identifier: lZILS1l6Km5aIGS6pA7P7azAJic
    NotBefore : 2015-01-30 20:44:40
    NotAfter  : 2016-01-30 20:44:40

    ca-signer (certsign):
    Alias     : ca-signer-1
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


An easy check to see if the signer token is working is to create a CRL::

    $ openxpkicmd  --realm democa crl_issuance
    Workflow created (ID: 511), State: SUCCESS

Adding the Webclient
^^^^^^^^^^^^^^^^^^^^

The package installs a default configuration for apache but requires that you
provide a tls certificate for the WebUI by yourself. So before you can start
the Webserver you **must** create a TLS certificate, place the key to
`/etc/openxpki/tls/private/openxpki.pem` and the certificate to `/etc/openxpki/tls/endentity/openxpki.crt`.

The default configuration also offers TLS client authentication. Place a copy of
your root certificate in `/etc/openxpki/tls/chain/` and run `c_rehash /etc/openxpki/tls/chain/`
to make it available for chain construction in apache.

You should now be able to start the apache server::

    $ service apache2 restart

Navigate your browser to *https://yourhost/openxpki/*. If your browser asks you to present a certificate
for authentication, skip it. You should now see the main authentication page.

You can log in as user with any username/password combination, the operator login has two preconfigured
operator accounts raop and raop2 with password openxpki.

If you only get the "Open Source Trustcenter" banner without a login prompt, check that fcgid is enabled
as described above with (``a2enmod fcgid; service apache2 restart``). If you get an internal server error,
make sure you have the *en_US.utf8* locale installed (``locale -a | grep en_US``)!

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

SCEP was moved to a new tool called *LibSCEP*, you need to install the library
and perl bindings yourself::

    apt install libcrypt-libscep-perl libscep

The SCEP logic is already included in the core distribution. The package installs
a wrapper script into */usr/lib/cgi-bin/* and creates a suitable alias in the apache
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

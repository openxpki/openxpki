.. _quickstart:

Quickstart guide
================

OpenXPKI is an easy-to-deploy and easy-to-use RA/CA software that makes
handling of certificates easy but nevertheless you should **really**
have some basic knowledge on what a PKI is. If you just want to see
"OpenXPKI in action" for a first impression of the tool, use the
public demo at https://demo.openxpki.org.

Support
-------

If you need help, please use
`the mailing list <https://lists.sourceforge.net/lists/listinfo/openxpki-users>`_
and do **NOT** open items in the issue tracker on GitHub. Personal support,
consulting and operational services are available from the founders of the project,
see the `project webpage for additional information <https://www.openxpki.org/#resources>`_.


Docker
------

We also provide a docker image based on the debian packages as well as a
docker-compose file, see https://github.com/openxpki/openxpki-docker.
**Please read the hints in the README if you try this on Windows!**


Configuration
-------------

The debian package come with a sample configuration which is identical
to the configuration repository at the time of package build. For a production
setup we recommend to remove the `/etc/openxpki` folder created by the package
and replace it with a checkout of the `community` branch of the configuration
repository available at https://github.com/openxpki/openxpki-config.
Please also have a look at
`README.md <https://github.com/openxpki/openxpki-config/blob/community/README.md>`_ and
`QUICKSTART.md <https://github.com/openxpki/openxpki-config/blob/community/QUICKSTART.md>`_
which have some more detailed instructions how to setup the system.

**Note**: The configuration is (usually) backward compatible but most releases
introduce new components and new configuration that can not be used with
old releases. Make sure your code version is recent enough to run the config!
Starting with v3.12, the code checks its compatibility with the config itself
via the `system.version.depend` node. We recommend to keep and maintain this
in your config!


Debian Builds
-------------

**Packages are for Debian 12 (Bookworm) / 64bit (arch amd64). The en_US.utf8
locale must be installed as the translation system will crash otherwise! The
packages do NOT work on Ubuntu or 32bit systems. Packages for
SLES/CentOS/RHEL/Ubuntu are available via an enterprise subscription**

Start with a debian minimal install, we recommend to add "SSH Server" and "Web Server"
in the package selection menu, as this will speed up the installation later.

To avoid an "untrusted package" warning, you should add our package signing key
(you might need to install gpg before)::

    wget https://packages.openxpki.org/v3/debian/Release.key -O - 2>/dev/null | \
    tee Release.key | gpg -o /usr/share/keyrings/openxpki.pgp --dearmor

The https connection is protected by a Let's Encrypt certificate but
if you want to validate the key on your own, the fingerprint is::

    gpg --print-md sha256 Release.key (Updated 2023-06-21)
    F88C6BFC 07ACE167 9399CDE5 21BD9148 4F9DA3EB B38E1BFC DA670B1C C96EB501

You can also find the key on the github repository in `package/debian/Release.key`.

Add the repository to your source list (bookworm)::

    echo -e "Types: deb\nURIs: https://packages.openxpki.org/v3/bookworm/\nSuites: bookworm\nComponents: release\nSigned-By: /usr/share/keyrings/openxpki.pgp" > /etc/apt/sources.list.d/openxpki.sources
    apt update

Please do not disable the installation of "recommend" packages as this will very
likely leave you with an unusable system.

As OpenXPKI can run with different RDBMS, the package does not list any of them as
dependency. You therefore need to install the required perl bindings and server
software yourself::

    apt install mariadb-server libdbd-mysql-perl

We strongly recommend to use a fastcgi module as it speeds up the UI, we recommend
mod_fcgid as it is in the official main repository (mod_fastcgi will also work but
is only available in the non-free repo)::

    apt install apache2 libapache2-mod-fcgid

Note, fastcgi module should be enabled explicitly, otherwise, .fcgi file will be
treated as plain text (this is usually done by the installer already)::

    a2enmod fcgid

Now install the OpenXPKI core package, session driver and the translation package::

    apt install libopenxpki-perl openxpki-cgi-session-driver openxpki-i18n

use the openxpkiadm command to verify if the system was installed correctly::

    openxpkiadm version
    Version (core): 3.28.0

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
While the ``MariaDB``drivers uses the old mysql binding the newer ``MariaDB2`` uses the
modern mariadb perl module which is the recommended driver on modern operating systems.
*Note:* It looks like the DBD::MariaDB module shipped with bookworm has an issue with reference
counters leading to very messy log output and **might** also have implications on security or
system stability - we therefore recommend to stick with the ``MariaDB`` module in combination
with the old ``libdbd-mysql-perl`` driver until there is a fixed version available.

Please create the empty database schema from the provided schema file. mariadb/mysql and
postgresql should work out of the box, the oracle schema is good for testing but needs some
extra indices to perform properly.

Example call when debian packages are installed::

    cat /usr/share/doc/libopenxpki-perl/examples/schema-mariadb.sql | \
         mysql -u root --password --database  openxpki

If you do not use debian packages, you can get a copy from ``contrib/sql/`` in the
config repository https://github.com/openxpki/openxpki-config.

Please also read `Session Storage`__ as you might need an additonal SQL user there.

System Setup
------------

Sample / Demo Configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The debian package comes with a shell script ``sampleconfig.sh`` that does all the work for you
(look in /usr/share/doc/libopenxpki-perl/examples/). The script will create a two-stage ca with
a root ca certificate and below your issuing ca and certs for SCEP and the internal datasafe.

It will also start the required services, you should be able to log into the system via the
webbrowser using the default credentials (see section `Testdrive`_ below).

This script provides a quickstart but should **never be used for production systems**
(it has the fixed passphrase *root* for all keys ;) and no policy/crl, etc config ).

Production Configuration
^^^^^^^^^^^^^^^^^^^^^^^^

For a production setup we recommend to remove the `/etc/openxpki` folder that was installed
by the package and use a checkout of the `openxpki-config repository at <https://github.com/openxpki/openxpki-config>`_.

Follow the steps in the README and QUICKSTART document to setup your production realms.

Testdrive
^^^^^^^^^

Navigate your browser to *https://yourhost/openxpki/*. If your browser asks you to present a certificate
for authentication, skip it. You should now see the main authentication page.

The sample configuration comes with a predefined handler for a local user database and also a set of
tests accounts. If you start with the configuration repository, the password for all accounts is
`openxpki`, if you start with the debian package the password is randomized during setup, you will see it
on the console during install and can find it in clear text in `/etc/openxpki/config.d/realm.tpl/auth/handler.yaml`

The usernames are `alice` and `bob` (users) and `rob`, `rose` and `raop` (operators). To setup your local
user database have a look at the files in the auth directory and the
`<reference/configuration/realm.html#authentication>`_

#. Login as User (Username: bob, Password: <see above>)
#. Go to "Request", select "Request new certificate"
#. Complete the pages until you get to the status "PENDING" (gray box on the right)
#. Logout and re-login as RA Operator (Username: raop, Password: <see above> )
#. Select "Home / My tasks", there should be a table with one request pending
#. Select your Request by clicking the line, change the request or use the "approve" button
#. After some seconds, your first certificate is ready :)
#. You can download the certificate by clicking on the link in the first row field "certificate"
#. You can now login with your username and fetch the certificate

Troubleshooting
^^^^^^^^^^^^^^^

If you only get the "Open Source Trustcenter" banner without a login prompt, make sure that the
fcgi module is properly loaded and available. To see the output of the wrapper script, it might
be helpful to use the browsers developer console (F12 or CTRL+F12 on most browsers).

If you get an internal server error, make sure you have the *en_US.utf8* locale installed
(``locale -a | grep en_US``)!

For further investigation, check `/var/log/openxpki/webui.log` and `/var/log/apache/error.log`.


Enabling the SCEP service
--------------------------

SCEP RA Certificate
^^^^^^^^^^^^^^^^^^^

Create a certificate to be used as SCEP RA, this is usually a TLS Server
certificate from the CA itself or signed by an external CA. Import the
certificate and register it as SCEP RA token::

    openxpkiadm alias --realm democa --token scep \
        --file scep.crt --key scep.pem

**Note**: Each realm needs his own SCEP token so you need to run this command
any realm that provides an SCEP service. It is possible to use the same SCEP
token in multiple realms.

Setup SCEP Endpoint
^^^^^^^^^^^^^^^^^^^

The SCEP setup is already included in the core distribution and example
configuration. The package installs a wrapper script and creates a suitable alias
redirecting all requests to ``http://host/scep/<any value>`` to the wrapper.
A default config is placed at /etc/openxpki/scep/default.conf. For a testdrive,
there is no need for any configuration, just call ``http://host/scep/scep``.

The system supports getcacert, getcert, getcacaps, getnextca and enroll/renew - the
shipped workflow is configured to allow enrollment with password or signer on behalf.
The password has to be set in ``scep.yaml``, the default is 'SecretChallenge'.
For signing on behalf, use the UI to create a certificate with the 'TLS Client'
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
-------------------------

OpenXPKI can assemble server generated keys into java keystores for
immediate use with java-based applications like tomcat. This requires
a recent version of java ``keytool`` installed. On debian, this is
provided by the package ``openjdk-7-jre``. Note: You can set the
location of the keytool binary in ``system.crypto.token.javajks``, the
default is /usr/bin/keytool.

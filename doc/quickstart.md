# Quickstart guide

OpenXPKI is an easy-to-deploy and easy-to-use RA/CA software that makes
handling of certificates easy but nevertheless you should **really**
have some basic knowledge on what a PKI is. If you just want to see
*OpenXPKI in action* for a first impression of the tool, use the
public demo at <https://demo.openxpki.org>.

## Support

If you need help, please use [the mailing
list](https://lists.sourceforge.net/lists/listinfo/openxpki-users) and
do **NOT** open items in the issue tracker on GitHub. Personal support,
consulting and operational services are available from the founders of
the project, see the [project webpage for additional
information](https://www.openxpki.org/#resources).

## Docker

We also provide a docker image based on the debian packages as well as a
docker-compose file, see <https://github.com/openxpki/openxpki-docker>.
**Please read the hints in the README if you try this on Windows!**

## Configuration

The debian package come with a sample configuration which is identical
to the configuration repository at the time of package build. For a
production setup we recommend to remove the `/etc/openxpki`
folder created by the package and replace it with a checkout of the
`community` branch of the configuration repository available
at <https://github.com/openxpki/openxpki-config>.

Please also have a look at
[README.md](https://github.com/openxpki/openxpki-config/blob/community/README.md)
and
[QUICKSTART.md](https://github.com/openxpki/openxpki-config/blob/community/QUICKSTART.md)
which have some more detailed instructions how to setup the system.

**Note**: The configuration is (usually) backward compatible but most
releases introduce new components and new configuration that can not be
used with old releases. Make sure your code version is recent enough to
run the config!

Starting with v3.22, there is mandatory cross check of config, database
schema and code via the `system.version.depend` node. We
recommend to keep and maintain this in your config!

## Debian Builds

**Packages are for Debian 12 (Bookworm) / 64bit (arch amd64). The
en_US.utf8 locale must be installed as the translation system will crash
otherwise! The packages do NOT work on Ubuntu or 32bit systems. Packages
for SLES/CentOS/RHEL/Ubuntu are available via an enterprise
subscription**

Start with a debian minimal install, we recommend to add *SSH Server*
and *Web Server* in the package selection menu, as this will speed up
the installation later.

To avoid an \"untrusted package\" warning, you should add our package
signing key (you might need to install gpg before):

```bash
wget https://packages.openxpki.org/v3/bookworm/Release.key -O - 2>/dev/null | \
    tee Release.key | gpg -o /usr/share/keyrings/openxpki.pgp --dearmor
```

The https connection is protected by a Let\'s Encrypt certificate but if
you want to validate the key on your own, the fingerprint is:

```bash
$ gpg --print-md sha256 Release.key (Updated 2025-05-16)
3FEB1721 48F53252 A6644B65 AD06304F 4751E129 510081E0 042E4E80 1175E3F8
```

You can also find the key on the [github repository](https://github.com/openxpki/openxpki) in
`package/debian/Release.key`.

Add the repository to your source list (bookworm):

```bash
echo -e "Types: deb\nURIs: https://packages.openxpki.org/v3/bookworm/\nSuites: bookworm\nComponents: release\nSigned-By: /usr/share/keyrings/openxpki.pgp" > /etc/apt/sources.list.d/openxpki.sources
apt update
```

Please do not disable the installation of \"recommend\" packages as this
will very likely leave you with an unusable system.

As OpenXPKI can run with different RDBMS, the package does not list any
of them as dependency. You therefore need to install the required perl
bindings and server software yourself:

```bash
apt install mariadb-server libdbd-mariadb-perl
```

Starting with v3.32 the webfrontend uses its own process and no longer
uses FCGI. The distributed configuration file is for the apache server
but you can run this with any server that has reverse proxy support. The
required mods are enabled by the package install:

```bash
apt install apache2
```

Now install the OpenXPKI core package, session driver and the
translation package:

```bash
apt install libopenxpki-perl openxpki-cgi-session-driver openxpki-i18n
```

use the oxi command to verify if the system was installed correctly:

```bash
$ oxi --version
OpenXPKI Community Edition v3.32.0
```

Now, create an empty database and assign a database user:

```sql
CREATE DATABASE openxpki CHARSET utf8;
CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
flush privileges;
```

...and put the used credentials into `/etc/openxpki/config.d/system/database.yaml`:

```yaml
main:
   debug: 0
   type: MariaDB2
   name: openxpki
   #host: localhost
   #port: 3306
   user: openxpki
   passwd: openxpki
```

Starting with the v3.8 release we added a MariaDB driver that makes use
of MariaDB internal sequences instead of the emulation code and we
recommend any new installations to use it! While the `MariaDB` drivers
uses the old mysql binding the newer `MariaDB2` uses the modern mariadb
perl module which is the recommended driver on modern operating systems.

Please create the empty database schema from the provided schema file.
mariadb/mysql and postgresql should work out of the box, the oracle
schema is good for testing but needs some extra indices to perform
properly.

Example call when debian packages are installed:

    cat /usr/share/doc/libopenxpki-perl/examples/schema-mariadb.sql | \
         mysql -u root --password --database  openxpki

If you do not use debian packages, you can get a copy from
`contrib/sql/` in the config repository
<https://github.com/openxpki/openxpki-config>.

Now create a user for the UI session storage

```sql
CREATE USER 'openxpki_session'@'localhost' IDENTIFIED BY 'mysecret';
GRANT SELECT, INSERT, UPDATE, DELETE ON openxpki.frontend_session
TO 'openxpki_session'@'localhost';
flush privileges;
```

...and put the used credentials into
/etc/openxpki/client.d/service/webui/default.yaml:

```yaml
# Properties of the session storage to manage the frontend session
session:
  driver: driver:openxpki
  params:
   DataSource: dbi:MariaDB:dbname=openxpki;host=localhost
   User:  openxpki_session
   Password: mysecret
```

## System Setup

### Sample / Demo Configuration

The debian package comes with a shell script `sampleconfig.sh` that does
all the work for you (look in /usr/share/doc/libopenxpki-perl/examples/).
The script will create a two-stage ca with a root ca certificate and below
your issuing ca and certs for SCEP and the internal datasafe.

It is required that the backend service is already up and running:

```bash
systemctl start openxpki-serverd
```

If successful, the script will start the webserver and OpenXPKI application server and you should be able to log into
the system via your webbrowser using the default credentials (see section
[Testdrive](#testdrive) below).

This script provides a quickstart but should **never be used for
production systems** (it has the fixed passphrase *root* for all keys
and no policy/crl, etc configured ).

### Production Configuration

For a production setup we recommend to remove the `/etc/openxpki`
folder that was installed by the package and use a checkout of the
[openxpki-config repository](https://github.com/openxpki/openxpki-config).

Follow the steps in the README and QUICKSTART document to setup your
production realms.

### Testdrive

Navigate your browser to <https://yourhost/webui/index/>. If your
browser asks you to present a certificate for authentication, skip it.
You should now see the main authentication page.

The sample configuration comes with a predefined handler for a local
user database and also a set of tests accounts. If you start with the
configuration repository, the password for all accounts is
`openxpki`, if you start with the debian package the
password is randomized during setup, you will see it on the console
during install and can find it in clear text in
`/etc/openxpki/config.d/realm.tpl/auth/handler.yaml`

The usernames are `alice` and `bob` (users) and `rob`, `rose` and `raop` (operators).
To setup your local user database have a look at the files in the `auth` directory and the
[authentication section in the realm configuration](reference/configuration/realm.html#authentication)

1.  Login as User (Username: bob, Password: \<see above\>)
2.  Go to \"Request\", select \"Request new certificate\"
3.  Complete the pages until you get to the status \"PENDING\"
4.  Logout and re-login as RA Operator (Username: raop, Password: \<see
    above\> )
5.  Select \"Home / My tasks\", there should be a table with one request
    pending
6.  Select your Request by clicking the line, change the request or use
    the \"approve\" button
7.  After some seconds, your first certificate is ready :)
8.  You can download the certificate by clicking on the link in the
    first row field \"certificate\"
9.  You can now login with your username and fetch the certificate

### Troubleshooting

If you only get the \"Open Source Trustcenter\" banner without a login
prompt, make sure that the fcgi module is properly loaded and available.
To see the output of the wrapper script, it might be helpful to use the
browsers developer console (F12 or CTRL+F12 on most browsers).

If you get an internal server error, make sure you have the *en_US.utf8*
locale installed (`locale -a | grep en_US`)!

For further investigation, check
`/var/log/openxpki-client/webui.log` and
`/var/log/apache/error.log`

## Enabling the SCEP service

### SCEP RA Certificate

Create a certificate to be used as SCEP RA, this is usually a TLS Server
certificate from the CA itself or signed by an external CA. Import the
certificate and register it as SCEP RA token:

```bash
oxi token add --realm democa --type scep --cert scep.crt --key scep.key
```

**Note**: Each realm needs its own SCEP token so you need to run this
command for any realm that provides an SCEP service. It is possible to
use the same SCEP token in multiple realms.

### Setup SCEP Endpoint

The SCEP setup is already included in the core distribution and example
configuration.

OpenXPKI requires an *endpoint* to be defined in your configuration, the
address of each endpoint is `http://yourhost/scep/<endpoint>`.

The path equals to the file name in the
`client.d/service/scep/` irectory, the default confiuration
deploys `generic.yaml` so you have to point your SCEP client
to `http://yourhost/scep/generic`. Please note that any
endpoint also requires an internal definiton inside the realm
configuration, a verbose example can be found in the file
`config.d/realm/democa/scep/generic.yaml`.

SCEP supports enrollment via challenge password as well as signing on
behalf. Advanced configuration is described in the scep workflow
section.

The best way for testing the service is the sscep command line tool (available at e.g. <https://github.com/certnanny/sscep>).

Check if the service is working properly at all:

```bash
mkdir tmp
./sscep getca -c tmp/cacert -u http://yourhost/scep/generic
```

Should show and download a list of the root certificates to the tmp
folder.

To test an enrollment:

```bash
openssl req -new -keyout tmp/scep-test.key -out tmp/scep-test.csr -newkey rsa:2048 -nodes
./sscep enroll -u http://yourhost/scep/generic \
    -k tmp/scep-test.key -r tmp/scep-test.csr \
    -c tmp/cacert-0 \
    -l tmp/scep-test.crt \
    -t 10 -n 1
```

Make sure you set the challenge password when prompted (default:
'SecretChallenge'). On current desktop hardware the issue workflow
will take approx. 10 seconds to finish and you should end up with a
certificate matching your request in the tmp folder.

## Support for Java Keystore

OpenXPKI can assemble server generated keys into java keystores for
immediate use with java-based applications like tomcat. This requires a
recent version of java `keytool` installed. On debian, this is provided
by the package `openjdk-7-jre`. Note: You can set the location of the
keytool binary in `system.crypto.token.javajks`, the default is
/usr/bin/keytool.

Hint: Most modern java applications work without any issues with
standard PKCS12 containers so you might want to try this as an
alternative.

# Quickstart Guide

OpenXPKI is an easy-to-deploy and easy-to-use RA/CA software that simplifies handling certificates. However, you should **really** have some basic knowledge about what a PKI is. If you just want to see "OpenXPKI in action" for a first impression, use the public demo at: [https://demo.openxpki.org](https://demo.openxpki.org).

## Support

If you need help, please use the [mailing list](https://lists.sourceforge.net/lists/listinfo/openxpki-users) and do **NOT** open items in the GitHub issue tracker. Personal support, consulting, and operational services are available from the project founders — see the [project webpage](https://www.openxpki.org/#resources) for more information.

## Docker

We provide a Docker image based on Debian packages, along with a `docker-compose` file: [https://github.com/openxpki/openxpki-docker](https://github.com/openxpki/openxpki-docker).
**Please read the hints in the README if you're trying this on Windows!**

## Configuration

The Debian package comes with a sample configuration identical to the configuration repository at the time of package build. For production setups, remove the `/etc/openxpki` folder created by the package and replace it with a checkout of the `community` branch of the configuration repository: [https://github.com/openxpki/openxpki-config](https://github.com/openxpki/openxpki-config).

Refer to [README.md](https://github.com/openxpki/openxpki-config/blob/community/README.md) and [QUICKSTART.md](https://github.com/openxpki/openxpki-config/blob/community/QUICKSTART.md) for detailed setup instructions.

> **Note:** Configuration is usually backward compatible, but new releases may introduce components not supported by older versions. Ensure your OpenXPKI code version is up-to-date. Starting with v3.22, configuration, database schema, and code are cross-checked via the `system.version.depend` node — this is now mandatory starting with v3.32.

## Debian Builds

**Packages are for Debian 12 (Bookworm) / 64bit (arch amd64). en\_US.utf8 locale must be installed. Not supported on Ubuntu or 32bit systems.**

### Preparation

We recommend starting with a minimal Debian install and selecting "SSH Server" and "Web Server" options.

Add our package signing key:

```bash
wget https://packages.openxpki.org/v3/bookworm/Release.key -O - 2>/dev/null | \
tee Release.key | gpg -o /usr/share/keyrings/openxpki.pgp --dearmor
```

The https connection is protected by a Let's Encrypt certificate but
if you want to validate the key on your own, the fingerprint is::

```bash
    $ gpg --print-md sha256 Release.key (Updated 2025-05-16)
    3FEB1721 48F53252 A6644B65 AD06304F 4751E129 510081E0 042E4E80 1175E3F8
```

You can also find the key on the github repository in `package/debian/Release.key`.

Add the repository to your sources:

```bash
echo -e "Types: deb\nURIs: https://packages.openxpki.org/v3/bookworm/\nSuites: bookworm\nComponents: release\nSigned-By: /usr/share/keyrings/openxpki.pgp" > /etc/apt/sources.list.d/openxpki.sources
apt update
```

Please do not disable the installation of "recommend" packages as this will very
likely leave you with an unusable system.

As OpenXPKI can run with different RDBMS and webservers, the package does not list
any of them as dependency. You therefore need to install the required perl bindings
and server software yourself:

```bash
apt install apache2 mariadb-server libdbd-mariadb-perl
```

Install OpenXPKI core package, session driver and the translation package:

```bash
apt install libopenxpki-perl openxpki-cgi-session-driver openxpki-i18n
```

Verify the installation:

```bash
oxi --version
OpenXPKI Community Edition v3.32.0
```

### Database Setup

Create an empty database and assign a database user:

```sql
CREATE DATABASE openxpki CHARSET utf8;
CREATE USER 'openxpki'@'localhost' IDENTIFIED BY 'openxpki';
GRANT ALL ON openxpki.* TO 'openxpki'@'localhost';
FLUSH PRIVILEGES;
```

Configure `/etc/openxpki/config.d/system/database.yaml`:

```yaml
main:
  debug: 0
  type: MariaDB2
  name: openxpki
  user: openxpki
  passwd: openxpki
```

Create the database schema from the provided schema file. MariaDB/mysql and
Postgresql should work out of the box, the oracle schema is good for testing
but needs some extra indices to perform properly. SQLite is only for testing
and must not be used in production.

```bash
cat /usr/share/doc/libopenxpki-perl/examples/schema-mariadb.sql | \
mysql -u root -p --database openxpki
```

If not using debian packages, see: `contrib/sql/` in [openxpki-config](https://github.com/openxpki/openxpki-config).

### UI Session Storage

Create a dedicated user for the UI session storage:

```sql
CREATE USER 'openxpki_session'@'localhost' IDENTIFIED BY 'mysecret';
GRANT SELECT, INSERT, UPDATE, DELETE ON openxpki.frontend_session TO 'openxpki_session'@'localhost';
FLUSH PRIVILEGES;
```

Connection details are configured in `/etc/openxpki/client.d/service/webui/default.yaml`:

```yaml
session:
  driver: driver:openxpki
  params:
    DataSource: dbi:MariaDB:dbname=openxpki;host=localhost
    User: openxpki_session
    Password: mysecret
```

Please note the different spelling, while the backend driver is named `MariaDB2`
for historic reasons, the driver in the session configuration must be the original
perl name `MariaDB`.

## System Setup

### Sample / Demo Configuration

Bring up the frontend and backend daemon:

```bash
systemctl start openxpki-clientd openxpkid
```

Run `sampleconfig.sh` from `/usr/share/doc/libopenxpki-perl/examples/`. It sets up a demo CA with certs and starts services.

**Do NOT use in production** — it has fixed passphrases and no security policies.

### Production Configuration

Remove `/etc/openxpki`, then use the [openxpki-config repository](https://github.com/openxpki/openxpki-config). Follow the README and QUICKSTART documents.

### Testdrive

Visit: `https://yourhost/webui/index/`

Sample users:

* `alice`, `bob` (users)
* `rob`, `rose`, `raop` (operators)

Password is `openxpki` (config repo) or shown during package install. If you missed it, you can find all users and passwords in the file `/etc/openxpki/config.d/realm.tpl/auth/handler.yaml`

#### Example Workflow

1. Login as User (Username: bob, Password: <see above>)
2. Go to "Request", select "Request new certificate"
3. Complete the pages until you get to the status "PENDING"
4. Logout and re-login as RA Operator (Username: raop, Password: <see above> )
5. Select "Home / My tasks", there should be a table with one request pending
6. Select your Request by clicking the line, change the request or use the "approve" button
7. After some seconds, your first certificate is ready :)
8. You can download the certificate by clicking on the link in the first row field "certificate"
9. You can now login with your username and fetch the certificate

### Troubleshooting

* Use journalctl to check the systemd units
* check the logs in the log folders `/var/log/openxpki-server` and
  `/var/log/openxpki-client`
* check the error log of the apache webserver

## Enabling the SCEP Service

### SCEP RA Certificate

Generate a TLS Server certificate via the WebUI and import it

```bash
oxi token add --realm democa --type scep --cert scep.crt --key scep.key
```

> Each realm needs its own SCEP token so you need to run this command
for any realm that provides an SCEP service. It is possible to use the same
SCEP token in multiple realms.

### SCEP Endpoint

OpenXPKI requires an *endpoint* to be defined in your configuration, the
address of each endpoint is `http://yourhost/scep/<endpoint>`.

The endpoint name equals to the file name in the `client.d/service/scep/`
directory, the default configuration deploys `generic.yaml` so you have to
point your SCEP client to `http://yourhost/scep/generic`. Please note that
any endpoint also requires an internal definiton inside the realm configuration,
a verbose example can be found in the file ``config.d/realm/democa/scep/generic.yaml``.

SCEP supports enrollment via challenge password as well as signing on behalf.

> The default configuration has `SecretChallenge` set as challenge password and requires the CN to end on `openxpki.test` to get an automated approval.

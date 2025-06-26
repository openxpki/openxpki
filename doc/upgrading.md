# Upgrading OpenXPKI

We try hard to build releases that do not break old installations but
sometimes we are forced to make changes that require manual adjustment
of existing config or even the database schema.

This page provides a summary of recommended and mandatory changes.
Recommended items should be done but the installation will continue to
work. Mandatory items MUST be done, as otherwise the system will not
behave correctly or even will not start.

For a quick overview of config changes, you should always check the
config repository at <https://github.com/openxpki/openxpki-config>.

## Release v3.32

**Important: a configuration update is required when upgrading to
v3.32**

This release has several breaking changes you must address when upgrading:

* Mandatory version identifiers in config
* Updates to YAML config due to new YAML parser
* Realm URLs must be unique
* New socket and permission layout
* Changed logfile locations (only with new frontend)

This release also introduces a new technical layer for the frontends
which comes with a new configuration layout and is the default when you
install the system from scratch. We recommend to migrate you existing
configuration to the new system. The old layer is still supported but
you need to make some minor adjustments to your configuration to run it.

### Socket and permissions

The frontend client now runs as a dedicated process and the communication
sockets are now inside `/run`, permissions and process logic is now handled
mostly by systemd. The socket of the backend client is now at
`/run/openxpkid/openxpkid.sock`, the package installer creates a symlink
if the old location exists but it is easier to just remove the socket
location from all config files as the new release assumes the new location
as default in any place.

The owner and group permissions have been changed for the new layout, if you
want to run the old frontend, you need to adjust the permission so the
webserver can talk to the backend!

### Mandatory Versioning

Add the depend node in the file `system/version.yaml`:

```yaml
depend:
  core: 3.32
  config: 2
```

You also *should* add a version identifier to the SQL tables, check if your
schema is up to date - instructions to add the schema are in the SQL files.

### YAML Update

OpenXPKI uses the pattern `+YYMMDD...` to specify relative dates in several
places. In the old configuration those are given as plain strings, e.g.

```yaml
validity:
    notafter: +01
```

The new YAML parser interpretes this as number and strips the leading
zeros which leads to unexpected behaviour and malformat errors. Please
review your configuration and add quotes around:

```yaml
validity:
    notafter: "+01"
```

### Logfiles

Folders for the logfiles are now created during package install, to not
interfere with legacy configurations the folders got new names.

#### Server Process

The new default location is `/var/log/openxpki-server`, but as the path
to the logfiles is explicitly given in the servers `log.conf` nothing
will change unless you upgrade your configuration to point to the new
target directory. The folder is now exclusive to the server daemon and
owned by `openxpki:pkiadm`, you *must* change your log.conf to enforce
the logfile owner to be `openxpki` as otherwise the daemon can not
create log files any longer.

#### Client (Frontend) Process

The new application server logs to `/var/log/openxpki-client`, the
target directory will not change if you stick with the old FCGI based
frontend wrappers.

### Realm URLs

Due to changes in the URL handling it is no longer possible to use
`/webui/index/` to log into the PKI with the old frontend code when only
one realm is configured. If you do not want to upgrade, use the realm map
and assign a dedicated name to your realm, e.g. `/webui/democa/`.

## Release v3.12

**Important: a configuration update is required when upgrading to
v3.12**

Major rework of the authentication layer - the handlers
`External` and `ClientSSO` that were also
referenced in the default configuration (but of no real use in the
default setup) have been **removed** from the code tree. A similar
functionality is available via the new handlers `NoAuth` and
`Command`. In case you have those handlers as \"leftovers\"
of the default configuration you should just remove them. If you have
used them, please adjust the configuration before you upgrade.

## Release v3.x

To upgrade from v2 or an earlier v3 installation to v3 please see the
Upgrade document in the openxpki-config repository.

In case you have written your own code or used the command line tools
please note that the old API was removed, and some output formats have
changed! You can find the API documentation as `perldoc` the
implementation classes (located in `OpenXPKI::Base::API::Plugin`).

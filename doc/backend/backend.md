# Backend

## Configuration System

The configuration is organized in YAML files split into areas:

- **`config.d/system/`** — system-wide settings (database, crypto, realm definitions)
- **`config.d/realm.tpl/`** — realm templates folder, hidden by the config layer
- **`config.d/realm/<name>/`** — realm-specific configuration

Configuration paths use dot notation, e.g. `system.database.main.type` refers to the file `config.d/system/database.yaml`, key `main.type`.

## Database Connection

OpenXPKI uses a relational database to store certificates, workflows, sessions, and audit logs. Connection parameters are configured in `config.d/system/database.yaml`.

### Supported Databases

| Driver | Module | Notes |
|---|---|---|
| `MariaDB2` | `libdbd-mariadb-perl` | **Recommended** for new installations |
| `MariaDB` | `libdbd-mysql-perl` | Deprecated, will be removed in a future release |
| `PostgreSQL` | `libdbd-pg-perl` | Fully supported |

> **Note:** Driver names are case-sensitive.

### Connection Parameters (`config.d/system/database.yaml`)

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

Without a `host` entry, a local Unix socket connection is used.

### Database Schema

The schema files are in `contrib/sql/`:

```bash
# MariaDB/MySQL
mysql -u root --password --database openxpki < contrib/sql/mariadb-backend-schema.sql
mysql -u root --password --database openxpki < contrib/sql/mariadb-frontend-schema.sql

# PostgreSQL
psql -U postgres openxpki < contrib/sql/postgresql-backend-schema.sql
psql -U postgres openxpki < contrib/sql/postgresql-frontend-schema.sql
```

---

## System Logging

OpenXPKI uses [Log4perl](https://metacpan.org/pod/Log::Log4perl) for logging. The configuration file is `/etc/openxpki/log.conf` (path configured in `config.d/system/server.yaml` under `log4perl`).

### Log Categories (Facilities)

| Facility | Logger path | Default level | Description |
|---|---|---|---|
| `AUTH` | `openxpki.auth` | INFO | Logins, logouts, authentication results |
| `AUDIT` | `openxpki.audit` | INFO | Access to private keys and secrets |
| `SYSTEM` | `openxpki.system` | WARN | Internal system events |
| `WORKFLOW` | `openxpki.workflow` | WARN | Internal workflow engine events |
| `APPLICATION` | `openxpki.application` | INFO | Workflow actions, certificate operations |
| `DEPRECATED` | `openxpki.deprecated` | WARN | Calls to deprecated code paths |
| Connector | `connector` | ERROR | Configuration layer / publication targets |
| Root | (all others) | ERROR | Catch-all for unassigned loggers |

### Special Appender Types

OpenXPKI comes with two special appenders which serve a special purpose and must
not be used outside the intended scope.

`OpenXPKI::Server::Log::Appender::Database` is used to write the workflow technical
log, it **must** bind to the `APPLICATION` target and **should** not log levels
higher than `INFO`.

`OpenXPKI::Server::Log::Appender::Audit` writes the audit track into the database,
it **must** bind to the `AUDIT` target. The audit log statements send key/value
pairs after the message compatible with the `warp_message = 0` configuration as
used in `Log::Log4perl::Layout::JSON`. The given default configuration creates
items in the audit table as JSON messages.

```ini
log4perl.appender.AuditDBI = OpenXPKI::Server::Log::Appender::Audit
log4perl.appender.AuditDBI.warp_message = 0
log4perl.appender.AuditDBI.layout = Log::Log4perl::Layout::JSON
log4perl.appender.AuditDBI.layout.field.message = %m{chomp}
```

### Changing the Log Level

To raise the log level for debugging, adjust the desired facility in `log.conf`:

```ini
# Workflow debugging
log4perl.category.openxpki.workflow = DEBUG, Logfile

# Full tracing (outputs unencrypted payload data!)
log4perl.category.openxpki.application = TRACE, ApplicationFile, ApplicationDBI
```

> **Warning:** `TRACE` level outputs unencrypted communication data and should only be activated briefly during debugging.

After changes to `log.conf`, it is required to restart the server backend `systemctl restart openxpki-serverd`

### Logrotate

A logrotate configuration is included with the Debian package. The important combination is `recreate: 1` in `log.conf` together with `delaycompress` in the logrotate configuration.


#  WebUI

The WebUI is configured in `client.d/service/webui/default.yaml`.

## Realm Routing

The WebUI supports the `path` routing mode, where the URL path segment determines the realm:

```yaml
realm:
    mode: path
    map:
        democa: democa
        rootca: rootca
```

The key on the left is the URL path segment (`/webui/democa/`), the value on the right is the internal realm name. Every new realm must be added here (see [Creating a Realm](../backend/realm.md#creating-a-realm)).

## Session Handler

The session handler manages frontend sessions. Configuration is in the `session` section of `client.d/service/webui/default.yaml`.

**Filesystem-based (default):**

```yaml
session:
    params:
        Directory: /tmp
```

**Database-based (recommended for multi-node deployments):**

```yaml
session:
    driver: driver:openxpki
    params:
        DataSource: dbi:MariaDB:dbname=openxpki;host=localhost
        User: openxpki_session
        Password: mysecret
```

**Note:** The package `openxpki-cgi-session-driver` is required for database-based sessions. It is strongly recommended to use a dedicated database user with access only to the `frontend_session` table:

```sql
CREATE USER 'openxpki_session'@'localhost' IDENTIFIED BY 'mysecret';
GRANT SELECT, INSERT, UPDATE, DELETE ON openxpki.frontend_session
TO 'openxpki_session'@'localhost';
```

**Session data encryption:**

Encrypts data using AES before storing it in the selected backend so it is opaque to administrators:

```yaml
session:
   EncryptKey: SessionSecret
```

**Session cookie encryption:**

Encrypt the value of the session cookie holding the internal session id:

```yaml
session:
   cookey: TheCookieMonster
```

**Session fingerprinting** prevents session hijacking by cookie theft. All listed variables must match, otherwise the session is discarded:

```yaml
session:
    fingerprint:
      - HTTP_ACCEPT_ENCODING
      - HTTP_USER_AGENT
      - HTTP_ACCEPT_LANGUAGE
      - REMOTE_USER
      - SSL_CLIENT_CERT
```

Variables that are not set or empty are ignored. When using X.509 client certificate authentication, include `SSL_CLIENT_CERT` so that the session is automatically invalidated when the external certificate expires.

## Additional WebUI Options

```yaml
global:
    staticdir: /var/www/static/    # directory for per-realm static content

# Security HTTP headers
header:
    Strict-Transport-Security: max-age=31536000;
    X-Frame-Options: SAMEORIGIN;
    X-XSS-Protection: "1; mode=block"
```

The `staticdir` directory must contain one subdirectory per realm (named after the realm) or a `_global` directory as a fallback.



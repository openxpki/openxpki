# Webservice

All frontend services are provided by the `openxpki-clientd` service, it starts
a second process which listens to requests via a unix socket and talks to the
backend via another socket.

## Reverse Proxy

You must use a webserver as reverse proxy to forward incoming HTTP requests
to the backend. A ready-to-use Apache configuration is included in
`contrib/apache2-openxpki-site.conf`.

The configuration expects:
- TLS key: `/etc/openxpki/tls/private/openxpki.pem`
- TLS certificate (with chain): `/etc/openxpki/tls/endentity/openxpki.crt`
- Root certificates for TLS client auth: `/etc/openxpki/tls/chain/` (after placing files: `c_rehash /etc/openxpki/tls/chain/`)

**Note: The webserver does not start when the `chain` path is empty! If you do not
need TLS client authentication, remove the related settings from the configuration.

## Frontend Server

After you have configured the above, start the frontend service with:

```bash
systemctl start openxpki-clientd
```


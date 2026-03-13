# Realm Configuration

## Concept

A *realm* is a fully isolated PKI environment within an OpenXPKI instance. Each realm has its own CA, certificate profiles, authentication configuration, and workflows. A single OpenXPKI instance can run multiple realms simultaneously (e.g. `democa` and `rootca`).

(creating-a-realm)=
## Creating a Realm

### Add the Realm Definition

Add a new entry to `config.d/system/realms.yaml`:

```yaml
myca:
    label: My Production CA
    baseurl: https://pki.example.com/webui/myca/
    description: Production CA for Example Corp
```

The key (`myca` here) is the internal name and must consist only of alphanumeric characters and underscores.

### Set Up the Directory Structure

The easiest approach is to create symlinks to the `realm.tpl` template and only copy the files that need customization:

```bash
mkdir -p config.d/realm/myca/{workflow/def,profile,notification}
cd config.d/realm/myca

# Shared configurations as symlinks
ln -s ../../realm.tpl/api/
ln -s ../../realm.tpl/auth/
ln -s ../../realm.tpl/crl/
ln -s ../../realm.tpl/crypto.yaml
ln -s ../../realm.tpl/uicontrol/

# Profiles: copy default (customizable), symlink template dir
cp ../../realm.tpl/profile/default.yaml profile/
ln -s ../../../realm.tpl/profile/template/ profile/

# Notifications: copy sample and adjust
cp ../../realm.tpl/notification/smtp.yaml.sample notification/smtp.yaml

# Workflows: global components as symlinks
ln -s ../../../realm.tpl/workflow/global workflow/
ln -s ../../../realm.tpl/workflow/persister.yaml workflow/

# Link all workflow definitions
(cd workflow/def && find ../../../../realm.tpl/workflow/def/ -type f | xargs -L1 ln -s)

# Remove unused workflows (optional)
cd workflow/def
rm est_* scep_*   # if EST/SCEP is not needed
```

### Add the Realm to the WebUI Realm Map

In `client.d/service/webui/default.yaml`, add the new realm to `realm.map` (mode `path`):

```yaml
realm:
    mode: path
    map:
        democa: democa
        rootca: rootca
        myca: myca      # new entry
```

The key on the left is the URL path segment, the value on the right is the internal realm name. The realm is then reachable at `https://yourhost/webui/myca/`.

---

(authentication)=
## Authentication

Authentication consists of two layers: **handlers** (the authentication mechanism) and **stacks** (the login options visible on the login page).

### Handlers (`auth/handler.yaml`)

A handler defines how credentials are verified:

**Anonymous** — no login required:
```yaml
Anonymous:
    type: Anonymous
    label: Guest User
```

**System** — for internal processes (hidden in the UI):
```yaml
System:
    type: Anonymous
    role: System
```

**ClientX509** — authentication with a TLS client certificate:
```yaml
Certificate:
    type: ClientX509
    role: User
    arg: CN              # which DN component is used as username
    trust_anchor:
        realm: democa    # only accept certificates from this realm
```

**Password (YAML file)** — password authentication against a local user file:
```yaml
LocalPassword:
    type: Password
    user@: connector:auth.connector.userdb
```

With this connector definition in `auth/connector.yaml`:
```yaml
userdb:
    class: Connector::Proxy::YAML
    LOCATION: /etc/openxpki/local/userdb.yaml
```

The user file has the following structure:

```yaml
alice:
    digest: "{ssha}JQ2BAoHQZQgecmNjGF143k4U2st6bE5B"
    role: User
    name: Anderson
    gname: Alice
    email: alice@example.com
```

You can also use argon2 or crypt based digest notation starting with the dollar sign `$`.

**LDAP/Active Directory** — authentication via an external directory service:
```yaml
raop-ad:
    class: Connector::Builtin::Authentication::LDAP
    LOCATION: ldap://ad.company.com
    base: dc=company,dc=loc
    binddn: cn=binduser
    password: secret
    filter: "(&(mail=[% LOGIN %])(memberOf=CN=RA Operator,OU=Groups,DC=company,DC=loc))"
```

### Stacks (`auth/stack.yaml`)

Stacks define the login options shown on the login page:

```yaml
Anonymous:
    label: Anonymous
    description: Access as guest without credentials
    handler: Anonymous
    type: anon

LocalPassword:
    label: User Login
    description: Login with username and password
    handler: LocalPassword
    type: passwd

Certificate:
    label: Client certificate
    description: Login using a client certificate
    handler: Certificate
    type: x509

# Internal, hidden in the UI
_System:
    handler: System
```

## Crypto Configuration

The token definition is done per realm in `config.d/realm/<realm>/crypto.yaml`.

The default configuration reads the PEM blocks of all required asymmetric keys from the database so there is no need to handle any key files on the nodes themselves.

The internal database encryption token is provided directly as AES secret inside the configuration.

For a standard setup using software keys, there is no need to change any of the settings in the `token` section.

### Passphrases and Secrets

The secret management can be done per realm via the `secret` section in the `crypto.yaml` file.

Secrets can either be provided literally in the configuration or provided after system startup via the WebUI.

**literal** — password stored directly in the configuration:

```yaml
secret:
    default:
        label: Global secret group
        method: literal
        value: my_passphrase
```

**plain/cache** — password is entered interactively after startup and cached:

```yaml
secret:
    default:
        label: CA signing key password
        method: plain
        cache: daemon
        kcv: $argon2id$v=19$...   # optional key check value for verification
```

The secrets are linked to the token layer via the `secret` parameter in the token section, the default configuration uses three secrets:

**default**

Protects the CA signing token

**ratoken**

Protects the SCEP / RA token - must have `export: 1` set to allow the secret to be handed over to the SCEP layer.

**svault**

Secret used as symmetric encryption key - **must** be a 64-character hex key (generate with: `openssl rand -hex 32`)

#### Secret sharing across realms

It is common to share the secrets across realms, in this case you can add the secret definitions in `system/crypto.yaml` and import them into the realm:

```yaml
secret:
    default:
        import: 1
```

This imports the secret from the global settings into the realm, non-literal secrets need to be entered once after startup in any realm and are afterwards available across all realms that reference it.

---

## CRL Configuration

The CRL configuration is in `crl/default.yaml`:

```yaml
validity:
    nextupdate: "+000014"   # CRL valid for 14 days
    renewal: "+000003"      # Issue a new CRL 3 days before the current one expires

digest: sha256

extensions:
    authority_key_identifier:
        critical: 0
        keyid: 1
        issuer: 0
```

Create a cronjob/timer to call `oxi workflow create --realm democa --type crl_issuance` in regular intervals to trigger CRL generation.

---

## Publishing

Publication of certificates and CRLs is configured via connector classes (`publishing.yaml`):

```yaml
entity:
    disk@: connector:publishing.connectors.local

crl:
    crl@: connector:publishing.connectors.cdp

cacert:
    disk-pem@: connector:publishing.connectors.cacert-pem
    disk-der@: connector:publishing.connectors.cacert-der

connectors:
    local:
        class: Connector::Builtin::File::Path
        LOCATION: /tmp/
        file: "[% ARGS.0.replace('[^\\w-]','_') %].crt"
        content: "[% pem %]"

    cdp:
        class: Connector::Builtin::File::Path
        LOCATION: /var/www/download/
        file: "[% ARGS.0.replace('[^\\w-]','_') %].crl"
        content: "[% der %]"
```

The `ARGS` parameter receives an array with one element which holds the `CN` of the certificate / CRL.

For LDAP publishing, use the class `Connector::Proxy::Net::LDAP::Single`.

---

## Email Notifications

Notifications are triggered from within workflows and configured in `notification/smtp.yaml`:

```yaml
backend:
    class: OpenXPKI::Server::Notification::SMTP
    host: localhost
    port: 25
    starttls: 0
    use_html: 1

default:
    to: "[% data.notify_to %]"
    from: no-reply@mycompany.local
    reply: helpdesk@mycompany.local

template:
    dir: /etc/openxpki/template/email/

message:
    csr_created:
        default:
            template: csr_created_user
            subject: CSR for [% cert_subject %]
        raop:
            template: csr_created_raop
            to: reg-office@mycompany.local
            subject: CSR for [% cert_subject %]

    cert_issued:
        default:
            template: cert_issued
            subject: Certificate issued for [% cert_subject %]
```

Email templates are stored as `.txt` (and optionally `.html`) files in the configured template directory. Template Toolkit is used for variable substitution.

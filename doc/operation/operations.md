# Operation

## Setting Up the oxi CLI

Many administrative commands require authentication via an EC key pair. This step is required once per user.

### Create a Key Pair

```bash
oxi cli create

# Output:
#     Please enter password to encrypt the key (empty to skip):
#     Please retype password:
#     ---
#     id: YIDR0GocM-e78JPI9dXoaDBYJxKiV2bE7Cy72ErFjg4
#     private: |
#         -----BEGIN EC PRIVATE KEY-----
#         ....
#         -----END EC PRIVATE KEY-----
#     public: |
#         -----BEGIN PUBLIC KEY-----
#         .....
#         -----END PUBLIC KEY-----
```

### Register the Public Key

Add the public key to `config.d/system/cli.yaml`:

```yaml
auth:
    admin:
        key: |
            -----BEGIN PUBLIC KEY-----
            MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
            -----END PUBLIC KEY-----
        role: RA Operator
```

The name (`admin`) is used for logging purposes only. The `role` determines which API commands may be executed.

### Deploy the Private Key

Place the private key at `~/.oxi/client.key`:

```bash
mkdir -p ~/.oxi && chmod 700 ~/.oxi
# Paste the private key from the oxi cli create output:
cat > ~/.oxi/client.key << 'EOF'
-----BEGIN EC PRIVATE KEY-----
...
-----END EC PRIVATE KEY-----
EOF
chmod 600 ~/.oxi/client.key
```

Alternatively: `oxi --auth-key /path/to/key.key <command>`

### Connection Test

```bash
oxi cli ping
# Expected output:
# ---
# result: ok
```

> **Note:** The OS user must be a member of the `openxpkiclient` group to access the backend socket.

---

## Setting Up the Datavault Token

The datavault token encrypts sensitive data in the datapool (e.g. private keys). It must be set up before all other tokens.

### Option 1: Symmetric Vault (recommended from v3.32)

Generate a 64-character hex key and enter it in `config.d/system/crypto.yaml`:

```bash
openssl rand -hex 32
# Output: a3f7c2...  (64 hex characters)
```

Enter the key in `config.d/system/crypto.yaml` under `secret.svault.value`:

```yaml
secret:
    svault:
        label: Secret group for datavault encryption
        method: literal
        value: <enter 64-character hex key here>
```

> **Important:** Keep this key in a safe place — it cannot be recovered. If lost, all encrypted data becomes permanently inaccessible.

### Option 2: Asymmetric Vault (key on filesystem)

Create the key and certificate:

```bash
mkdir -p -m755 /etc/openxpki/local/keys
cd /etc/openxpki/local/keys

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:3072 -aes-256-cbc \
    -out vault-1.pem

openssl req -config /etc/openxpki/contrib/vault.openssl.cnf -x509 -days 365 \
    -key vault-1.pem -out vault-1.crt

chmod 400 vault-1.pem
chown openxpki:openxpki vault-1.pem
```

Import the certificate and register it as a token:

```bash
oxi certificate add --cert vault-1.crt
oxi token add --realm democa --type datasafe --cert vault-1.crt
```

Token functional test:

```bash
oxi api get_token_info --realm democa -- alias=datasafe-1
# key_usable: 1 must appear in the output
```

---

## Setting Up CA Tokens

### Import the Root CA

In a two-tier hierarchy, import the root CA certificate first:

```bash
oxi token add --realm rootca --type certsign --cert rootca.crt
```

If you have multiple root CAs, import all of them. Intermediate certificates without their own token are imported with `oxi certificate add`. Always start with the self-signed root.

### Set Up the Issuing CA

Issuing CA keys and certificates must be created externally. Recommended tool: [clca](https://github.com/openxpki/clca)

**Keys stored in the database (default):**

```bash
oxi token add --realm democa --type certsign \
    --cert issuingca.crt --key issuingca.key
```

The command imports the certificate, encrypts the private key, and stores it in the datapool. The output shows the generated alias (on initial setup: `ca-signer-1`).

**Keys stored on the filesystem:**

Place the key in `/etc/openxpki/local/keys/<realm>/` (permissions: 0400, owner: `openxpki`), then:

```bash
oxi token add --realm democa --type certsign --cert issuingca.crt
# without --key, since the key is on the filesystem
```

### Verify the Token List

```bash
oxi token list --realm democa
# Output:
# ---
# token_groups:
#   ca-signer:
#     active: ca-signer-1
#     count: 1
#     token:
#     - key_usable: 1
#       key_store: DATAPOOL
```

### Functional Test: Create a CRL

```bash
oxi workflow create --realm democa --type crl_issuance
# state: SUCCESS confirms the signing token is working
```

---

## Setting Up the SCEP/RA Token

The SCEP token is a TLS server certificate that serves as the SCEP RA signing token:

```bash
oxi token add --realm democa --type scep \
    --cert ratoken.crt --key ratoken.key
```

> **Note:** Each realm needs its own SCEP token. The same certificate can be used in multiple realms.

---

## Token Rollover

When a token expires or is compromised, add a new one. OpenXPKI manages tokens via generation numbers:

```bash
# Add a new issuing CA token (automatically receives the next generation number)
oxi token add --realm democa --type certsign \
    --cert newissuingca.crt --key newissuingca.key

# Verify the token list after import
oxi token list --realm democa
```

The new token is automatically set as the active token. Certificates issued under the old token remain associated with it (important for CRL issuance).

---

## Status and Diagnostics

### Check Token Status

```bash
# List all tokens in a realm
oxi token list --realm democa

# Detailed info for a specific token
oxi api get_token_info --realm democa -- alias=ca-signer-1
```

### System Status

```bash
# Test backend connectivity
oxi cli ping

# Run the system status workflow
oxi workflow create --realm democa --type status_system
```

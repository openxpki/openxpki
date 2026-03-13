# Certificate Profiles

A certificate profile is the template that defines all technical properties of a certificate: subject composition, key usage, extensions, and allowed key types.

## Profile Structure

Profiles are located in `config.d/realm/<name>/profile/`. 

Settings in the `default.yaml` file are applied to all profiles, any other file in the directory represents an individual profile with the filename being the internal profile name.

The `template` folder holds reusable field definitions to compose the subject and info sections.

---

## Available Profiles

The sample configuration includes the following profiles:

| Profile | File | Description |
|---|---|---|
| `tls_server` | `tls_server.yaml` | TLS server certificates (web, API) |
| `tls_client` | `tls_client.yaml` | TLS client authentication |
| `tls_dual` | `tls_dual.yaml` | Combined server and client use |
| `ocsp_responder` | `ocsp_responder.yaml` | OCSP signer certificate |
| `user_auth_enc` | `user_auth_enc.yaml` | User authentication and encryption |
| `sample` | `sample.yaml` | Reference profile with all options as a template |

---

## Parameters

### Algorithms

```yaml
key:
    alg:
      - rsa
      - ec

    enc:
      - aes256

    generate: both   # 'server' = server-side only, 'client' = upload only, 'both' = either

    rsa:
        key_length:
          - 3072      # default (first in the list = default selection)
          - 2048
          - 4096
          - 2048:4096  # range: accept any length between 2048 and 4096

    ec:
        curve_name:
          - prime256v1
          - secp384r1
          - secp521r1
```

Values prefixed with an underscore (e.g. `_1024`) are accepted when validating uploaded keys, but are not shown in the UI for key generation.

The `generate` setting is used by the UI based request workflow to determine if the user is allowed/forced to use server-side key generation or must provide a CSR. This setting has no effect on automated enrollment workflows.

### Validity

Relative time values use the format `+YYMMDDhhmmss`, for example:

```yaml
validity:
    notafter: "+01"      # 1 year
    # notafter: "+0006"  # 6 months
    # notafter: "+000014" # 14 days
```

> **Note:** Relative dates must be quoted, otherwise the YAML parser strips leading zeros.

Absolute dates are also supported: `notafter: 20301231235959`

---

## Subject Composition

The subject is defined using *styles*. A style specifies:
- which fields the user must enter in the UI (sections `subject`, `san`, `info`)
- how the certificate subject DN and SANs are rendered from those fields

### Example: TLS Server Profile

```yaml
style:
    00_basic_style:
        label: Basic Style
        ui:
            subject:
                - hostname
                - hostname2
                - application_name
            info:
                - requestor_realname
                - requestor_email
                - comment

        subject:
            dn: >
                CN=[% hostname.lower %]
                [% IF application_name %]:[% application_name %][% END %],
                DC=Test Deployment,DC=OpenXPKI,DC=org
            san:
                dns:
                  - "[% hostname.lower %]"
                  - "[% FOREACH entry = hostname2 %][% entry.lower %] | [% END %]"
```

The subject DN and SANs are rendered from the user-entered fields using Template Toolkit.

For SCEP/EST/RPC there is an additional `enroll` style that takes the subject directly from the CSR:

```yaml
    enroll:
        subject:
            dn: CN=[% CN.0 %],DC=Test Deployment,DC=OpenXPKI,DC=org
            san:
                dns: "[% FOREACH entry = SAN_DNS %][% entry.lower %] | [% END %]"
                ip : "[% FOREACH entry = SAN_IP %][% entry %] | [% END %]"
```

---

## Field Definitions

Fields can be defined directly in a profile or as reusable templates in `profile/template/`. 

### Field Definition Structure

```yaml
id: hostname
label: I18N_OPENXPKI_UI_PROFILE_HOSTNAME
placeholder: fully.qualified.example.com
type: freetext          # freetext | select
match: \A [A-Za-z\d\-\.]+ \z
preset: "[% CN.0.replace(':.*','') %]"
width: 60
```

| Parameter | Description |
|---|---|
| `id` | Internal key in the workflow context |
| `label` | Display label (I18N key or literal text) |
| `type` | `freetext` (text input) or `select` (dropdown) |
| `match` | Regex validation of user input |
| `preset` | Pre-fill from an existing CSR (Template Toolkit) |

**Example `select` field:**

```yaml
id: affiliation
type: select
option:
  - Staff
  - Customer
  - Partner
```

**Preset examples:**
```yaml
preset: CN.0             # first CN element
preset: OU.X             # all OU elements (one field per element)
preset: "[% CN.0.replace(':.*','') %]"  # Template Toolkit expression
```

## Extensions

Extensions are defined as a baseline in `default.yaml` and can be overridden in individual profiles.

### Default Extensions

```yaml
extensions:
    basic_constraints:
        critical: 1
        ca: 0

    subject_key_identifier:
        critical: 0
        hash: 1

    authority_key_identifier:
        critical: 0
        keyid: 1
        issuer: 0

    crl_distribution_points:
        critical: 0
        uri:
            - http://pki.example.com/download/[% ISSUER.CN.0.replace(' ','_') %].crl

    authority_info_access:
        critical: 0
        ca_issuers: http://pki.example.com/download/[% ISSUER.CN.0.replace(' ','_') %].cer
        ocsp: http://ocsp.example.com/
```

The values `ISSUER.CN.0` etc. are replaced at issuance time with the actual values from the signing CA certificate.

### Profile-specific Extensions

The `keyUsage` and `extendedKeyUsage` bits can be set per profile (also see `sample.yaml` for the full reference). You can omit any false values, only items given with a literal `1` are added.

```yaml
extensions:
    key_usage:
        critical: 1
        digital_signature: 0
        non_repudiation:   0
        key_encipherment:  0
        data_encipherment: 0
        key_agreement:     0
        key_cert_sign:     0
        crl_sign:          0
        encipher_only:     0
        decipher_only:     0

    extended_key_usage:
        critical: 0
        # these are OIDs, some OIDs are known and have names
        client_auth:      0
        server_auth:      0
        email_protection: 0
        code_signing:     0
        time_stamping:    0
        ocsp_signing:     0
        # Any other oid can be given by number
        # MS SmartCard Login
        1.3.6.1.4.1.311.20.2.2: 0
        # IPSec Tunnel releated OIDs
        1.3.6.1.5.5.8.2.2: 0
        1.3.6.1.5.5.7.3.6: 0
        1.3.6.1.5.5.7.3.7: 0

```

**Custom keyUsage OIDs:**

You can add any custom OID to the keyUsage sections using: 

```yaml
extensions:    
    extended_key_usage:
        # MS SmartCard Login
        1.3.6.1.4.1.311.20.2.2: 0
```

**Custom OIDs**

You can add arbitrary OID as extensions:

```yaml
extensions:   
    oid:
        1.3.6.1.4.1.311.20.2:
            critical: 0
            format: ASN1
            encoding: UTF8String
            value: Machine

        1.3.6.1.4.1.311.21.7:
            critical: 0
            format: ASN1
            encoding: SEQUENCE
            value: |
               field1=OID:1.3.6.1.4.1.311.21.8.15138236.9849362.7818410.4518060.12563386.22.5003942.7882920
               field2=INT:100
               field3=INT:0
```





**TLS Client (`tls_client.yaml`):**

```yaml
extensions:
    key_usage:
        critical: 1
        digital_signature: 1

    extended_key_usage:
        critical: 0
        client_auth: 1
```

## Metadata

Profiles can define metadata fields that are stored in the database along with the certificate:

```yaml
metadata:
    requestor: "[% requestor_realname %]"
    email: "[% requestor_email %]"
    owner_contact: "[% owner_contact || requestor_email %]"
    entity: "[% hostname FILTER lower %]"
```

This metadata is searchable and filterable in the WebUI.

---

## Publishing

To publish a certificate on issuance, add the publication target:

```yaml
publish:
  - disk    # publishes via the 'disk' connector in publishing.yaml
```

Multiple publishing targets are possible. The target definition is in `publishing.yaml` of the respective realm.

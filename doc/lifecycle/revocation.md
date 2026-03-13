# Certificate Revocation Request (WebUI)

The revocation request workflow handles certificate revocation requests.

## Workflow Flow

### Initialization

The workflow is created with the certificate identifier to revoke
(`cert_identifier`) plus optional revocation parameters:

- **`reason_code`** – one of the standard CRL reason codes (see below)
- **`comment`** – free-text explanation
- **`invalidity_time`** – date/time the compromise or problem occurred
  (used in the CRL entry; must not be in the future)
- **`delay_revocation_time`** – future point in time at which the certificate
  should actually be revoked (workflow pauses until then)

### User Review

The request is present to the requester for review, chosen values can be changed if needed. Once submitted, the
workflow looks for other existing pending revocation workflows for the same
certificate, sends a pending notification and puts the request to the operator queue for approval.

### Approval

The operator has to approve or reject the request. On approval the certificate changes into *revocation pending* status and waits for the next CRL issuance to be picked up. As soon as a new CRL was created, the certificate status changes to *revoked*. 

### Delayed Revocation

If `delay_revocation_time` is set to a future timestamp, the approved
workflow pauses itself (`delay_revocation` activity) until that time.
The wakeup is handled by the workflow engine; no manual action is needed.
This is useful for scheduling revocation in advance, for example to give
administrators time to replace a certificate before it disappears from
trust stores.

## Reason Codes

The `reason_code` field accepts the standard RFC 5280 CRL reason codes
(CamelCase as used by OpenSSL):

| Reason Code | Meaning |
|-------------|---------|
| `unspecified` | No specific reason given |
| `keyCompromise` | Private key is known or suspected to be compromised |
| `cACompromise` | CA key compromised (used for CA certificates) |
| `affiliationChanged` | Subject's affiliation has changed |
| `superseded` | Certificate has been replaced by a new one |
| `cessationOfOperation` | Entity is no longer operating |


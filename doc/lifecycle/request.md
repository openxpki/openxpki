# Certificate Signing Request (WebUI)

The signing request workflow is the standard WebUI-driven
workflow for requesting certificates. It supports both client-provided CSRs
(PKCS#10 upload) and server-side key generation, and guides the requester
step-by-step through profile selection, subject entry, and submission.

## Workflow Flow

The workflow proceeds through these major phases:

### Profile Selection

The requester picks a certificate profile and subprofile. Profiles are
configured under `realm/<realm>/profile/` and drive the available subject
fields, SANs, and key generation options.

### Request Type

The requester chooses how the key pair is provided:

- **Upload PKCS#10**: The requester generates the key pair externally and
  uploads a CSR. The workflow immediately checks for duplicate keys.
- **Server-generated key**: The server generates the key pair on behalf of
  the requester. Key algorithm and parameters are selected here; the private
  key is stored encrypted in the datapool and can be picked up after issuance.
  The server will provide the requester with a password which is required later
  to pickup the generated key.

Which options appear is controlled by the profile's key generation mode.

### Subject Entry

The requester fills in subject fields depending on what the selected profile's
subject style defines. If a CSR was provided, fields can be preset from the
values found in the CSR.

If configured, the requester has to provide additional meta information which
are required to process the request, e.g. ticket number, responsibility, etc.
Provided metadata can be persisted with the certificate if needed.

### Subject Review

A summary screen shows the rendered subject, SAN list, and the results of
all policy checks. If no violations are present, the requester submits the
request. If violations exist, they must either fix the subject or explicitly
acknowledge the violation with a comment before proceeding.

#### Policy Checks

Any FQDN used in the certificate is checked against DNS, failure to resolve it
is considered a policy violation.

A certificate with the same subject which is not inside the configured renewal
interval raises a *subject duplicate* violation.

### Pending / Approval

After submission the workflow sends a pending notification and enters the
approval queue. An operator must review and approve the request before
the certificate is issued. See [Approval](#approval).

### Issuance and Success

Once approved, the certificate is issued, metadata is persisted, a
notification is sent, and the workflow publishes the certificate. The final
`SUCCESS` state displays the certificate identifier, subject, validity, and
profile.

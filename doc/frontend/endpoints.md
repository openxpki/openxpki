# Endpoints & Protocols

OpenXPKI supports several protocols for certificate enrollment: SCEP, EST, JSON-RPC. All protocols share a similar configuration pattern and use the same `certificate_enroll` workflow for the enrollment but have protocol specific options and workflows for other actions.

The WebUI configuration is different and explained in a separate chapter.

## Configuration Concept

Endpoint configuration is split into a frontend and a backend part, the most common approach is to have a one-on-one relation between the exposed frontend and the policy configuration in the backend by using the same name on both sides:

- **`client.d/service/<protocol>/<endpoint>.yaml`**
- **`config.d/realm/<name>/<protocol>/<endpoint>.yaml`**

The filename (without `.yaml`) in `client.d/service/<protocol>/` is the endpoint name and determines the URL:

| Protocol | URL pattern | Example |
|---|---|---|
| SCEP | `http://yourhost/scep/<endpoint>` | `http://yourhost/scep/generic` |
| EST | `https://yourhost/.well-known/est/<endpoint>/` | `https://yourhost/.well-known/est/default/` |
| RPC | `https://yourhost/rpc/<endpoint>` | `https://yourhost/rpc/generic` |
| ACME | `https://yourhost/acme/<endpoint>` | `https://yourhost/acme/generic` |
| SimpleCMC | `https://yourhost/cmc/<endpoint>` | `https://yourhost/cmc/generic` |

> ACME and SimpleCMC are only available in the enterprise version of OpenXPKI.

### Frontend Configuration

#### Common settings

All protocols share a common subset of settings:

```yaml
global:
    # Defines to which realm the request is dispatched
    realm: democa

locale:
    # if set any I18N based error messages are translated
    language: en_US

logger:
    # Log level: overrides system.logger.level
    # "DEBUG" MIGHT disclose sensitive user input data.
    # "TRACE" WILL dump unfiltered communication.
    level: INFO

auth:
    # The auth stack to use
    # _System is the unauthenticated / anonymous stack that works in all protocols
    stack: _System
```

(environment-mapping)=
#### Environment mapping

All protocol wrappers support the mapping of values from the webserver environment into the workflow context.

The keyword is equal to the name of the parameter in the workflow and have to be specified as list under the key `env` in the protocols action section.

| Key            | Mapped value                                                 |
| -------------- | ------------------------------------------------------------ |
| client_ip  | remote IP address                                          |
| user_agent   | HTTP User-Agent header                                       |
| endpoint     | endpoint name (can be used in combination with a fixed `servername` if both values should be made available) |
| server       | endpoint name (mutually exclusive with `servername` )        |
| signer_cert  | authentication certificate PEM block (origin depends on protocol) |
| signer_dn    | DN of the authentication certificate |
| signer_chain | list of PEM blocks of chain certificates |
| tls_client_cert  | PEM of the certificate used in mTLS |
| tls_client_dn   | DN of the certificate used in mTLS |
| tls_client_chain | list of PEM blocks of chain used in mTLS |
| pkcs7            | original PKCS7 content as PEM block |

The `pkcs7` and  `tls_*` parameters are only available in the RPC frontend.

#### Endpoint expansion

The above mentioned frontend/backend relation is based on the special workflow parameter `server` which is used to build the path to the backend configuration. The parameter can be set in two ways:

##### Explicit

```yaml
global:
    servername: my_policy_config_path
```

Sets the parameter `server` to the fixed value `my_policy_config_path`.

The policy config will then be expected at `config.d/realm/<realm>/<protocol>/my_policy_config_path.yaml` and **not** adhere to the name of the frontend path. As this makes debugging more complex you should use such setups only if there is a special need for it.

##### Implicit

The implicit variant copies the name of the endpoint as extracted from the original HTTP request route to the parameter `server`, e.g. an EST call to `/.well-known/est/printers/simpleenroll` will result in `server = printers` so the policy is expected at `config.d/realm/<realm>/est/printers.yaml`.

To enable this behavior, you must have the `server` parameter in your [environment mapping](#environment-mapping).

### Backend Configuration

The backend configuration file is read by the invoked workflow. The common settings for the enrollment process are explained in the end of the section for the default [enrollment workflow](../lifecycle/enrollment.md).

## Enrollment Protocols

### SCEP (Simple Certificate Enrollment Protocol)

Handles SCEP requests including the `GetNextCACert` message for automated CA rollover.

#### Output configuration

The node `output` in the frontend configuration has two properties `chain` and `header`.

The `chain` parameter defines what certificates should be included into the certificate response for enrollment requests, the default is to include the end-entity and its chain certificates without the root `chain: chain`. To also get the root set `chain: fullchain`, to not send any chain set `chain: none`

The parameter `headers` has only a single supported value `all` - when set the endpoint exposes workflow id, transaction id and literal error messages via HTTP headers.

```yaml
output:
    chain: fullchain
    headers: all
```

#### Enrollment workflow configuration

The node `PKIOperation` holds options for the enrollment request, the minimal required configuration if endpoint expansion is used is:

```yaml
PKIOperation:
    env:
     - server
```

This starts the `certificate_enroll` workflow with the PKCS10 container and signer certificate extracted from the SCEP request.

##### Additional input parameters

You can use HTTP query parameters to transport additional information along with the request and map them into the workflow:

```yaml
PKIOperation:
    input:
     - printer_mac
```

This will find a parameter `printer_mac` in the query parameters and make its value available as `url_printer_mac` in the workflow. Note the `url_` prefix which is used to prevent unexpected injection. Only scalar values are allowed, any non-word character is removed from the value.

#### Property request configuration

The name of the nodes are equal to the name of operation as defined in the protocol: `GetCACert`, `GetCACAPS`, `GetNextCACert`, `GetCRL` .

All nodes support the parameter `env` for [environment mapping](#environment-mapping).

The workflow to be executed defaults to `scep_<lowercased operation name>`, e.g. `scep_getcacert` for the `GetCACert` but can be customized setting `workflow: my_scep_property_workflow`.

```yaml
GetCACert:
    workflow: my_scep_property_workflow
    env:
     - server
     - client_ip
```

This will start a workflow of type `my_scep_property_workflow` with the parameters `server` and `client_ip`.

### EST (Enrollment over Secure Transport, RFC 7030)

EST endpoints are available at `/.well-known/est/<endpoint>/`, the default "unnamed" endpoint uses the configuration found in `default.yaml`.

#### Transport configuration

EST implies the usage of HTTPS as transport. For security reasons the frontend refuses to accept requests via plain HTTP.

To disable this check in special environments, e.g. when using a reverse proxy set:

```yaml
global:
    insecure: 1
```

#### Output configuration

The node `output` in the frontend configuration has a single property `header`.

The parameter `headers` has only a single supported value `all` - when set the endpoint exposes workflow id, transaction id and literal error messages via HTTP headers.

```yaml
output:
    headers: all
```

#### Enrollment workflow configuration

The default configuration already includes the `server` and `signer_cert` environment items for endpoint expansion and mTLS evaluation so it is possible to run an EST endpoint with no additional configuration.

If a custom configuration is required, you can use the node names equal to the EST actions `simpleenroll` and `simplereenroll` to set a different `workflow` or pass additional `env` variables.

#### Property request configuration

The name of the nodes are equal to the name of operation as defined in the protocol: `csrattrs` and `cacerts`.

All nodes support the parameter `env` for [environment mapping](#environment-mapping).

The workflow to be executed defaults to `est_<operation name>`, e.g. `est_cacerts` for `cacerts` operation but can be customized setting `workflow: my_est_certs_workflow`.

#### Smoke test with curl

```bash
# Retrieve CA certificates
curl -k https://yourhost/.well-known/est/default/cacerts | \
    openssl base64 -d | openssl pkcs7 -inform DER -print_certs

# Query CSR attributes
curl -k https://yourhost/.well-known/est/default/csrattrs

# Enrollment
openssl req -new -newkey rsa:2048 -nodes \
    -subj "/CN=test.example.com" -keyout client.key \
    -outform der | openssl base64 -out client.csr

curl -k -X POST \
    -H "Content-Type: application/pkcs10" \
    --data-binary @client.csr \
    https://yourhost/.well-known/est/default/simpleenroll
```

---

## RPC (JSON-RPC)

The JSON RPC wrapper can be used to interface with any workflow configured in the OpenXPKI backend. The default configuration includes an example to interact with the default enrollment workflow to achieve a similar behaviour as with SCEP or EST.

### Input configuration

The recommended way to interact with the RPC layer is a HTTP POST request with a proper content type and raw JSON payload as body. To prevent performance issues or attacks with deeply nested payloads you must enable and limit the processing explicitly:

```yaml
input:
    allow_raw_post: 1
    parse_depth: 5
```

If you want to use *JSON Object Signing and Encryption* to authenticate your requests, you need to create an empty node `jose` on the top level:

```yaml
# Enable JOSE (JSON Object Signing and Encryption)
jose: ~
```

### Output configuration

Use the `output` node to activate HTTP status code mapping. This will render input failures to the workflow into 400 and processing errors into 500 errors. If this is not set, the status code is always 200 (as long as the server is working at all).

```yaml
output:
    use_http_status_codes: 1
```

### Method configuration

Each method in the endpoint YAML maps an API method name to an OpenXPKI workflow, names must start with an uppercase letter and must contain only letters and numbers.

```yaml
RequestCertificate:
    workflow: certificate_enroll
    input:
      - pkcs10
      - profile
      - comment
    output:
      - cert_identifier
      - certificate
      - chain
      - error_code
    env:
      - signer_cert
      - server
    pickup:
        workflow: check_enrollment
        input:
          - pkcs10
          - transaction_id

RevokeCertificate:
    workflow: certificate_revoke
    input:
      - cert_identifier
      - reason_code
      - comment
    preset:
        reason_code: unspecified
    env:
      - signer_cert
    output:
      - error_code
```

| Parameter | Description |
|---|---|
| workflow | Internal workflow name |
| input | Fields taken from the request body |
| output | Fields returned in the response |
| env | Fields filled automatically from the server environment |
| pickup | Workflow and parameters for polling deferred results |
| preset | Default values passed as input parameters, overridden by request values of the same name |

### OpenAPI Support

Endpoints can be given an OpenAPI title used for the auto-generated API documentation:

```yaml
openapi:
    title: Public Certificate API
```

The OpenAPI documentation is then available at `https://yourhost/rpc/<endpoint>?format=openapi`.


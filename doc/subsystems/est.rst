EST Endpoint / RFC 7030
#######################

The default configuration comes with a preconfigured endpoint for the
"Enrollment over Secure Transport" Protocol as defined in RFC 7030.

As defined by the protocol the URL is `https://<your host>/.well-known/est/`,
the endpoint maps simple(re)enroll to the `certificate_enroll` workflow in a
similar way as SCEP or RPC. The CACerts and CSRAttrs call is also supported
and backed by a workflow that sends sane defaults suitable for most purposes.
The wrapper does **not** support the FullCMC protocol.

The only thing you might need to adjust in the wrapper configuration is the
name of the ca realm in case you have more than one. For further details
please see the RPC and the common wrapper configuration sections.

The configuration for the default URL is done via the file
`<myrealm>/est/default.yaml`, you can load another configuration by using a
`calabel` which loads the policy from est/<calabel>.yaml.


Default Configuration
======================

The default configuration supports anonymous enrollment with manual approval
via UI or automatic issuance using Enrollment on Behalf with a signer
certificate.

Smoke Test
----------

```bash
openssl req -keyout /dev/null -subj "/CN=test me" -nodes -new -newkey rsa:3072 -outform der -out - | base64 > test.pem
curl -v -H "Content-Type: application/pkcs10" --data @test.pem  https://demo.openxpki.org/.well-known/est/simpleenroll
```

This should return `202 Request Pending - Retry Later (a37b7b4de066026425b2c05eaa42b15ae936be6c)`
which indicates that the request was queued for approval. Log into the UI to approve the request
and rerun the same line to fetch your certificate, *hint*: the value in the brackets is the transaction
id assigned to this request by the PKI which you can use to find / identify the correct workflow.


Authenticated Test
------------------

Use the UI to obtain a TLS Client certificate with the application name `pkiclient` and add
it to the query using the curl options `--key/--cert`. You should now get your certificate immediately.

```bash
openssl req -keyout /dev/null -subj "/CN=test me" -nodes -new -newkey rsa:3072 -outform der -out - | base64 > test.pem
curl -s -H "Content-Type: application/pkcs10" --data @test.pem \
   --key estclient/deadbeaf.key.pem --cert estclient/deadbeaf.cert.pem \
   https://demo.openxpki.org/.well-known/est/simpleenroll | base64 -d | openssl pkcs7 -inform der -print_certs
```

Note: The EST standard states that only the end-entity certificate must be included in the response. To get the chain
certificates query the cacerts method of the endpoint:

To obtain the chain certificates, run

```bash
curl -s https://demo.openxpki.org/.well-known/est/cacerts | base64 -d | openssl pkcs7 -inform der -print_certs
```

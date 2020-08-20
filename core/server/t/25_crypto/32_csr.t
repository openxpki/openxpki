use strict;
use warnings;

# Core modules
use Test::More tests => 7;
use Test::Exception;
use MIME::Base64;

use utf8;

BEGIN { use_ok "OpenXPKI::Crypt::PKCS10" }

my $csr = "-----BEGIN CERTIFICATE REQUEST-----
MIIC2TCCAcECAQAwgZMxEzARBgoJkiaJk/IsZAEZFgNvcmcxGDAWBgoJkiaJk/Is
ZAEZFghPcGVuWFBLSTEfMB0GCgmSJomT8ixkARkWD1Rlc3QgRGVwbG95bWVudDEY
MBYGCgmSJomT8ixkARkWCEdhcmRlbmVyMScwEAYDVQQDDAlTeWx0ZXTDuHkwEwYK
CZImiZPyLGQBAQwFTW9sdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
AQDeDsHKkzDYlv7BG8+J2ysFHXnJuLcX29Vf0noITOoP4hQYOJb8L7CocFmijknZ
2UxRqsADrUmhWiye9EieykuhvNC36VVzEcB5EuboYHPyVKgQhI3dA7XqvE1+U8Gs
pvVufNP9Fe0tWRLleO+4Hl3e31QheaG0B9+AXo78vUYGNdEQFkWZxeWEdMuY/n+L
MojnJzKhBYc/R1f+gSNDJHzPDA1mecCGyRl+Hz/5vEXdBfMY4KQUNQBmrt9tuD2X
Hg8z0HEFRHAugR90hFf+KMBWPrTBZ5QpxQ6raXfDbjEeiBm1O05KYr0Fwk1xDnov
zTPnTPFmbob+i9anynOrkFAHAgMBAAGgADANBgkqhkiG9w0BAQsFAAOCAQEAKxYM
YyiGoQ14rBbvm+x+c7ijdfF5dcClDQHw5icmg+Kd9qeQtF9Yvcgn6wjlpeJC0XXD
tq3q5Fb/vAbfyqK3Q056M/CGojGcmWKHKtZsvGD3uFMkKaTy9DZ4BQqAbPHz6S3R
35mbPC1j0CTj0HkKjzlsDB/RJk0fVwdP9equfzqFYV3aRXEa1JSSPgCkDcymm+Bf
HxU5jx0BojRJPVB1pgTwjR3SHp0GZIblixHjkV7/ZXeXzuQtX/XCChMWFpqpjEpR
Uc2JuR8ecxfLzS6Iz/njfO9qcfHoZXPW5sXputFAH1UBxYeuUwpEVKioqoGRZ2Jr
X/jkJOJJjNm9VQ9+Zg==
-----END CERTIFICATE REQUEST-----";

my $pkcs10;

lives_and { $pkcs10 = OpenXPKI::Crypt::PKCS10->new($csr); ok $pkcs10 } "new instance";

is $pkcs10->get_subject_key_id, "51:8B:77:CE:BD:AE:64:4D:7D:5E:56:33:04:07:1A:9A:89:F8:EE:BE", "Subject Key ID";
is $pkcs10->get_subject, "UID=Molte,CN=Syltetøy,DC=Gardener,DC=Test Deployment,DC=OpenXPKI,DC=org", "Subject";
is $pkcs10->get_transaction_id, "c8a70ecaa1882ae6ac57bff0e4fb9d44d5b75911", "Transaction ID";
is $pkcs10->get_digest, "1c3fa3b3781d63ddfca4f5264e2a9ac0d882efb7", "Digest";

my $csr_identifier = $pkcs10->get_csr_identifier;
$csr_identifier =~ tr/-_/+\//;
my @hex_bytes = unpack("(A2)*", $pkcs10->get_transaction_id);
is pack('H2' x 20, @hex_bytes), decode_base64($csr_identifier), "decoded Transaction ID == decoded CSR Identifier";

1;

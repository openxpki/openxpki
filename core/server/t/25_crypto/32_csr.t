use strict;
use warnings;

use Test::More;
use Test::Exception;
use MIME::Base64;
use utf8;
use English;

BEGIN { use_ok "OpenXPKI::Crypt::PKCS10" }

# ---------------------------------------------------------------------------
# Original RSA-2048 CSR (UTF-8 subject, challengePassword, no extensions)
# ---------------------------------------------------------------------------
my $csr_legacy = "-----BEGIN CERTIFICATE REQUEST-----
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

# RSA-2048 CSR with extensions (SAN, KeyUsage, EKU) and challengePassword
my $rsa_csr = '-----BEGIN CERTIFICATE REQUEST-----
MIIDCTCCAfECAQAwNzEVMBMGA1UEAwwMUlNBIENTUiBUZXN0MREwDwYDVQQKDAhU
ZXN0IE9yZzELMAkGA1UEBhMCREUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQDimRPX5DAvXa9PFFADHAEhdP5AH9bTuHbjzbz+AhGUW/tUXFGQ4yU0KhlJ
Vu/nQuazhgacZYMjffxZsyFGzkL1skJHCrhj5SAqKJw6/o1fCHMzw4VwNZh2raYi
El6NWMr/N2XZZLSNmdYLEjvKcgNPUiaqsuRVBrd+11+3CRCDdZF7QfzdLqCWag2w
YSPUnNDIvnyn3c1R+V+3/A+bziu1q6I6QB7sj7wQkfRr/og6sGCIhmeFr0afBMVi
gCFuQ+XhpGdUPp6Wpwu2FV/O6Y5JEz56h3O1zPr7NUvQ8lxbDXw+SXskfU0YJoXE
Mj9TkwyuneBu1YdBlhPR/aMt2OK7AgMBAAGggYwwFQYJKoZIhvcNAQkHMQgMBnMz
Y3IzdDBzBgkqhkiG9w0BCQ4xZjBkMDMGA1UdEQQsMCqCE3JzYS1jc3IuZXhhbXBs
ZS5jb22BE3JzYS1jc3JAZXhhbXBsZS5jb20wDgYDVR0PAQH/BAQDAgWgMB0GA1Ud
JQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjANBgkqhkiG9w0BAQsFAAOCAQEAY0Co
ve2YAvni2FRQL/bVXYma7VgL+QYDJud3x6gvyitDId3swIjWk8DQ4hP+j34rn+tD
SwB6Tt55LMpSv0xrACOoS8Thr0sLrhGqZg00OTK7f//qDC7eexgVq11BDab0P/Pt
2927nteI3e+UE/cVbBwhuc25POnAJZJJ/qNCu+awu1bkzdtencRcvr8AC51EQRCF
jPjuH1OBKjvBr+RfCXFU0AWWQs9iBPViPtb10YYFrXeVwtPPF400MsdHtbtUbOqN
Fb6SKShm40q1EiVtwkmxRX0l8uqV3nqWnJh15HY6D8W4bHgnb0q5yUM6jaBs45L0
vClqnOba5ccGj7PwEA==
-----END CERTIFICATE REQUEST-----';

# RSA-PSS-2048 CSR (rsassaPss key + PSS signature, SHA-256, saltlen=32)
my $rsapss_csr = '-----BEGIN CERTIFICATE REQUEST-----
MIIDJjCCAdoCAQAwOjEYMBYGA1UEAwwPUlNBUFNTIENTUiBUZXN0MREwDwYDVQQK
DAhUZXN0IE9yZzELMAkGA1UEBhMCREUwggFRMDwGCSqGSIb3DQEBCjAvoA8wDQYJ
YIZIAWUDBAIBBQChHDAaBgkqhkiG9w0BAQgwDQYJYIZIAWUDBAIBBQADggEPADCC
AQoCggEBAMoYlf0qSDM6a/zWP8TkD9Z8zJfmHFlHGNxBc+AitBcZ4+m1BXdl90Jc
qJRO0xPvADyjwryoI78JrvTP/XKOg05LFJnTUnzpbg3tbf+5SIecYPigXQXSioCZ
PQq4WSTlu+T6h9TFRdTrYwm26/z2YU1qWgUAcfF3wWAkitjAMrP03+iZh7/A4dub
1y/uLI0KYZCYJm0S/ffEskxGEiLMIXS77PyRs+8ZnY1A3FFZYNsMOtWwVrA7M5L3
uYMd8+B/jeBNKmCUlduKMlJ8ZD+KyCo69nWpAf2szKT9+CQiGTH/VI3FoxSsq7jp
tX9IGrIviaUaCXdSDPsSx1aLyIzBbdMCAwEAAaBEMEIGCSqGSIb3DQEJDjE1MDMw
IQYDVR0RBBowGIIWcnNhcHNzLWNzci5leGFtcGxlLmNvbTAOBgNVHQ8BAf8EBAMC
B4AwQQYJKoZIhvcNAQEKMDSgDzANBglghkgBZQMEAgEFAKEcMBoGCSqGSIb3DQEB
CDANBglghkgBZQMEAgEFAKIDAgEgA4IBAQCv12ggNbwn/HrDy+ix35duIzqvOkGp
mJbg/zyF0dSXD9eJC4QesvabYgZepmDqeYn3YFlRsZ7snu/KEXmcZZ8MK7NVujjw
gq0MUdpGMwBnS+8RuHZId88Ue3ujpYBXKTB0pxkdLt0EjcOKZPaCkDSAS1q26mg4
5vrPRWyeCUg33bS/yrgHWybQiYKRPtKhqIpGQt26KaKlGr4Cfn0Fd1K5iX6gs5Rv
tPBIT2gHJ62K1s6HEmaEiPDN69WJxUKYVwquptWsYCW/hCYTQFEHhkr1kZs6UwbZ
FHY7wEMEqtoIYVWQ6Hnw2QfUEuMM8+Y5wQS4/6TeoEm/mjiEKzhY7Gpb
-----END CERTIFICATE REQUEST-----';

# EC P-256 CSR (ECDSA-SHA256, DNS + IP SAN, KeyUsage, EKU)
my $ec_csr = '-----BEGIN CERTIFICATE REQUEST-----
MIIBTDCB8wIBADA2MRQwEgYDVQQDDAtFQyBDU1IgVGVzdDERMA8GA1UECgwIVGVz
dCBPcmcxCzAJBgNVBAYTAkRFMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAENkQ4
QiJFQyer9O1l+p6pprFZkHPMikCdt4DaHEuYcEUZvh1Al4HROUH2fed2laP0QDVj
CtoOK2VKkaQDjI9OgqBbMFkGCSqGSIb3DQEJDjFMMEowIwYDVR0RBBwwGoISZWMt
Y3NyLmV4YW1wbGUuY29thwQKAAABMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUEDDAK
BggrBgEFBQcDATAKBggqhkjOPQQDAgNIADBFAiEAmBFrBjE/KPAoOqmWkFIu2NiP
uW1J+1lSj73duPe17RcCICggGOynMy9klEH9ST8wm2A3n1IJ6Dt4glPv4r9dY5xR
-----END CERTIFICATE REQUEST-----';

# EC P-256 CSR whose subject exercises the less common RDN attribute OIDs
# (emailAddress, serialNumber, unstructuredName, unstructuredAddress)
my $rdn_csr = '-----BEGIN CERTIFICATE REQUEST-----
MIIBPzCB5wIBADCBhDEVMBMGA1UEAwwMUkROIENTUiBUZXN0MSIwIAYJKoZIhvcN
AQkBFhNyZG4tY3NyQGV4YW1wbGUuY29tMREwDwYDVQQFEwhDU1I5ODc2NTEXMBUG
CSqGSIb3DQEJAgwIY3NyLWhvc3QxGzAZBgkqhkiG9w0BCQgMDDE5OC41MS4xMDAu
NzBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABOUgWyfriNddBu4FDhB3Q68xqQrp
DTB+UhzkqvLsTvEmKm/dO39YI20Xrql9Y3HLHeave4jUUehmn5fkL5h8nSqgADAK
BggqhkjOPQQDAgNHADBEAiAF1ETQsekJD2Iu3lw9PsfOAPw5QoZhON3OVfX1+OjQ
vwIgIFuPW953sG+qJM0qOXv9EMPnz3xv6M+oU9xViCJnF6o=
-----END CERTIFICATE REQUEST-----';

# ---------------------------------------------------------------------------
# Original CSR – backward-compat checks
# ---------------------------------------------------------------------------
subtest 'original RSA CSR (UTF-8 subject, legacy)' => sub {
    my $pkcs10;
    lives_and { $pkcs10 = OpenXPKI::Crypt::PKCS10->new($csr_legacy); ok $pkcs10 } 'new instance';

    is $pkcs10->get_subject_key_id,
        '51:8B:77:CE:BD:AE:64:4D:7D:5E:56:33:04:07:1A:9A:89:F8:EE:BE',
        'Subject Key ID';
    is $pkcs10->get_subject,
        'CN=Syltetøy+UID=Molte,DC=Gardener,DC=Test Deployment,DC=OpenXPKI,DC=org',
        'Subject (UTF-8)';
    is $pkcs10->get_transaction_id,
        'c8a70ecaa1882ae6ac57bff0e4fb9d44d5b75911',
        'transaction_id';
    is $pkcs10->get_digest,
        '1c3fa3b3781d63ddfca4f5264e2a9ac0d882efb7',
        'digest';

    my $csr_id = $pkcs10->get_csr_identifier;
    $csr_id =~ tr/-_/+\//;
    my @hex_bytes = unpack('(A2)*', $pkcs10->get_transaction_id);
    is pack('H2' x 20, @hex_bytes), decode_base64($csr_id),
        'transaction_id == decoded csr_identifier';
};

# ---------------------------------------------------------------------------
# RSA-2048 CSR – comprehensive accessor coverage
# ---------------------------------------------------------------------------
subtest 'RSA-2048 CSR' => sub {
    my $x = OpenXPKI::Crypt::PKCS10->new($rsa_csr);
    ok($x, 'parsed');

    # Identity / encoding
    like($x->pem, qr/^-----BEGIN CERTIFICATE REQUEST-----/, 'pem header');
    is($x->get_identifier,      'pKG3lLMZohcRC1BM5nTVMB0o-jM', 'identifier');
    is($x->get_csr_identifier,  'pKG3lLMZohcRC1BM5nTVMB0o-jM', 'csr_identifier alias');
    is($x->get_transaction_id,  'a4a1b794b319a217110b504ce674d5301d28fa33', 'transaction_id');
    is($x->get_digest,          '4a5ada67337bd1416ba89e7c8da13fb13ecf724a', 'digest');

    # transaction_id == SHA1 over DER == decoded csr_identifier
    my $csr_id = $x->get_csr_identifier;
    $csr_id =~ tr/-_/+\//;
    my @hex = unpack('(A2)*', $x->get_transaction_id);
    is(pack('H2' x 20, @hex), decode_base64($csr_id), 'transaction_id equals decoded csr_identifier');

    # Subject DN
    is($x->get_subject, 'C=DE,O=Test Org,CN=RSA CSR Test', 'subject');
    is_deeply($x->subject_hash, { CN => ['RSA CSR Test'], O => ['Test Org'], C => ['DE'] }, 'subject_hash');
    is($x->cn, 'RSA CSR Test', 'cn');

    # Public key
    is($x->get_public_key_alg,           'RSA',  'key algorithm RSA');
    is($x->get_key_params->{key_length}, 2048,   'key length 2048');
    ok(!defined $x->get_key_params->{curve_name}, 'no curve_name for RSA');
    ok(length($x->get_pub_key)    > 0, 'get_pub_key returns bytes');
    ok(length($x->get_spki_der)   > 0, 'get_spki_der returns bytes');
    is($x->get_public_key_hash,
        'FA:75:3A:33:ED:10:20:CD:1B:80:A3:5E:AF:AB:35:34:FE:10:41:38',
        'public_key_hash');
    is($x->get_subject_key_id,
        'FA:75:3A:33:ED:10:20:CD:1B:80:A3:5E:AF:AB:35:34:FE:10:41:38',
        'subject_key_id falls back to public_key_hash');

    # Signature
    is($x->get_signature_digest, 'sha256', 'signature digest sha256');
    is($x->check_signature, 1, 'RSA self-signature valid');

    # Extensions (from extensionRequest attribute)
    my $exts = $x->extensions;
    ok(exists $exts->{'2.5.29.15'}, 'extensions map has KeyUsage OID');
    ok(exists $exts->{'2.5.29.17'}, 'extensions map has SAN OID');
    ok(exists $exts->{'2.5.29.37'}, 'extensions map has EKU OID');

    # KeyUsage
    my $ku = $x->get_key_usage;
    ok($ku, 'KeyUsage present');
    ok($ku->critical, 'KeyUsage critical');
    ok((grep { $_ eq 'digitalSignature' } @{$ku->bits}), 'KeyUsage: digitalSignature');
    ok((grep { $_ eq 'keyEncipherment'  } @{$ku->bits}), 'KeyUsage: keyEncipherment');

    # EKU
    my $eku = $x->get_ext_key_usage;
    ok($eku, 'EKU present');
    ok((grep { $_ eq 'serverAuth' } @{$eku->usages}), 'EKU: serverAuth');
    ok((grep { $_ eq 'clientAuth' } @{$eku->usages}), 'EKU: clientAuth');

    # No BasicConstraints in CSR
    is($x->get_basic_constraints, undef, 'no BasicConstraints');

    # SAN
    my $san = $x->get_subject_alt_name;
    is(scalar @$san, 2, 'two SAN entries');
    is_deeply($san->[0], ['DNS',   'rsa-csr.example.com'],  'SAN DNS');
    is_deeply($san->[1], ['email', 'rsa-csr@example.com'],  'SAN email');

    # cert_subject_parts merges DN + SAN
    my $parts = $x->get_cert_subject_parts;
    is_deeply($parts->{CN},        ['RSA CSR Test'],        'subject_parts CN');
    is_deeply($parts->{SAN_DNS},   ['rsa-csr.example.com'], 'subject_parts SAN_DNS');
    is_deeply($parts->{SAN_EMAIL}, ['rsa-csr@example.com'], 'subject_parts SAN_EMAIL');

    # get_extension_value by OID returns raw DER
    my $ku_der = $x->get_extension_value('2.5.29.15');
    ok(defined $ku_der && length($ku_der) > 0, 'get_extension_value by OID returns DER');

    # get_extension_value by unknown name returns undef
    is($x->get_extension_value('certificatePolicies'), undef, 'absent extension returns undef');

    # No custom/PEN extensions
    is_deeply($x->get_custom_extension,     [], 'no custom extensions');
    is_deeply($x->get_cert_extension_parts, {}, 'no cert extension parts');

    # Attribute access – challengePassword
    is($x->get_attribute_value('challengePassword'), 's3cr3t', 'challengePassword by name');
    my $raw_attr = $x->get_attribute_value('1.2.840.113549.1.9.7');
    ok(ref($raw_attr) eq 'ARRAY' && @$raw_attr == 1, 'challengePassword by OID returns arrayref with one element');
    # raw element is DER-encoded (tag+length+value), unpack to verify content
    like(unpack('H*', $raw_attr->[0]), qr/733363723374$/, 'raw DER contains challengePassword bytes');

    # Unknown attribute name/OID → undef
    is($x->get_attribute_value('unknownAttr'), undef, 'unknown attr name → undef');
    is($x->get_attribute_value('1.2.3.4.5'),   undef, 'absent OID → undef');
};

# ---------------------------------------------------------------------------
# RSA-PSS-2048 CSR – PSS key and signature
# ---------------------------------------------------------------------------
subtest 'RSA-PSS-2048 CSR' => sub {
    my $x = OpenXPKI::Crypt::PKCS10->new($rsapss_csr);
    ok($x, 'parsed');

    is($x->get_identifier,     'Wo37Vt9iujI3AIwNpTqxH9KqF44', 'identifier');
    is($x->get_transaction_id, '5a8dfb56df62ba3237008c0da53ab11fd2aa178e', 'transaction_id');
    is($x->get_digest,         '1fac419de4ce5445aaf1f1ca4edb87ae298dc579', 'digest');
    is($x->get_subject, 'C=DE,O=Test Org,CN=RSAPSS CSR Test', 'subject');
    is($x->cn, 'RSAPSS CSR Test', 'cn');

    # Key
    is($x->get_public_key_alg,           'RSA',  'key algorithm RSA (PSS)');
    is($x->get_key_params->{key_length}, 2048,   'key length 2048');
    ok(!defined $x->get_key_params->{curve_name}, 'no curve_name');
    ok(length($x->get_pub_key)    > 0, 'get_pub_key non-empty');
    ok(length($x->get_spki_der)   > 0, 'get_spki_der non-empty');
    is($x->get_public_key_hash,
        '37:A3:3A:56:1B:A7:76:38:C1:87:70:3C:A4:0E:22:09:08:C1:3F:14',
        'public_key_hash');

    # PSS signature
    is($x->get_signature_digest, 'pss', 'signature digest pss');
    is($x->check_signature, 1, 'RSA-PSS self-signature valid');

    # KeyUsage from extensionRequest
    my $ku = $x->get_key_usage;
    ok($ku, 'KeyUsage present');
    ok($ku->critical, 'KeyUsage critical');
    is_deeply($ku->bits, ['digitalSignature'], 'KeyUsage: digitalSignature');

    is($x->get_ext_key_usage, undef, 'no EKU');

    # SAN
    is_deeply($x->get_subject_alt_name, [['DNS', 'rsapss-csr.example.com']], 'SAN DNS');

    # No challengePassword
    is($x->get_attribute_value('challengePassword'), undef, 'no challengePassword');
};

# ---------------------------------------------------------------------------
# EC P-256 CSR – EC key params and ECDSA signature
# ---------------------------------------------------------------------------
subtest 'EC P-256 CSR' => sub {
    my $x = OpenXPKI::Crypt::PKCS10->new($ec_csr);
    ok($x, 'parsed');

    is($x->get_identifier,     '8DyWWKnN8FkBNZQzHN4wh8QXb1s', 'identifier');
    is($x->get_transaction_id, 'f03c9658a9cdf059013594331cde3087c4176f5b', 'transaction_id');
    is($x->get_digest,         'd19d2db70fa271123fc519f5c20992e6e100e328', 'digest');
    is($x->get_subject, 'C=DE,O=Test Org,CN=EC CSR Test', 'subject');
    is($x->cn, 'EC CSR Test', 'cn');

    # EC key
    is($x->get_public_key_alg,             'EC',          'key algorithm EC');
    is($x->get_key_params->{key_length},   256,           'key length 256');
    is($x->get_key_params->{curve_name},   'prime256v1',  'curve prime256v1');
    ok(length($x->get_pub_key)    > 0, 'get_pub_key non-empty');
    ok(length($x->get_spki_der)   > 0, 'get_spki_der non-empty');
    is($x->get_public_key_hash,
        '16:0E:9D:22:39:28:C1:77:F5:6C:F2:8C:59:74:82:3F:74:54:9F:33',
        'public_key_hash');
    is($x->get_subject_key_id,
        '16:0E:9D:22:39:28:C1:77:F5:6C:F2:8C:59:74:82:3F:74:54:9F:33',
        'subject_key_id falls back to public_key_hash');

    # Signature
    is($x->get_signature_digest, 'sha256', 'signature digest sha256');
    is($x->check_signature, 1, 'ECDSA self-signature valid');

    # KeyUsage
    my $ku = $x->get_key_usage;
    ok($ku, 'KeyUsage present');
    ok($ku->critical, 'KeyUsage critical');
    is_deeply($ku->bits, ['digitalSignature'], 'KeyUsage: digitalSignature only');

    # EKU
    my $eku = $x->get_ext_key_usage;
    ok($eku, 'EKU present');
    is_deeply($eku->usages, ['serverAuth'], 'EKU: serverAuth');

    # SAN: DNS + IPv4
    my $san = $x->get_subject_alt_name;
    is(scalar @$san, 2, 'two SAN entries');
    is_deeply($san->[0], ['DNS', 'ec-csr.example.com'], 'SAN DNS');
    is_deeply($san->[1], ['IP',  '10.0.0.1'],           'SAN IPv4');

    # cert_subject_parts
    my $parts = $x->get_cert_subject_parts;
    is_deeply($parts->{SAN_DNS}, ['ec-csr.example.com'], 'subject_parts SAN_DNS');
    is_deeply($parts->{SAN_IP},  ['10.0.0.1'],           'subject_parts SAN_IP');

    # No challengePassword
    is($x->get_attribute_value('challengePassword'), undef, 'no challengePassword');
};

# ---------------------------------------------------------------------------
# RDN attribute mapping – emailAddress / serialNumber /
# unstructuredName / unstructuredAddress
# ---------------------------------------------------------------------------
subtest 'RDN attribute mapping' => sub {
    my $x = OpenXPKI::Crypt::PKCS10->new($rdn_csr);
    ok($x, 'parsed');

    is($x->cn, 'RDN CSR Test', 'cn');

    # The textual subject must use the human readable RDN names for the
    # less common attribute OIDs:
    #   1.2.840.113549.1.9.1 => emailAddress
    #   1.2.840.113549.1.9.2 => unstructuredName
    #   1.2.840.113549.1.9.8 => unstructuredAddress
    #   2.5.4.5              => serialNumber
    is($x->get_subject,
        'unstructuredAddress=198.51.100.7,unstructuredName=csr-host,'
        . 'serialNumber=CSR98765,emailAddress=rdn-csr@example.com,CN=RDN CSR Test',
        'subject renders RDN attribute names');

    # subject_hash uses the uppercased attribute names as keys
    is_deeply($x->subject_hash, {
        CN                  => ['RDN CSR Test'],
        EMAILADDRESS        => ['rdn-csr@example.com'],
        SERIALNUMBER        => ['CSR98765'],
        UNSTRUCTUREDNAME    => ['csr-host'],
        UNSTRUCTUREDADDRESS => ['198.51.100.7'],
    }, 'subject_hash keyed by RDN attribute names');
};

done_testing;

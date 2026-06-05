use strict;
use warnings;
use Test::More;

use_ok "OpenXPKI::Crypt::X509";

# Original EC test certificate (prime256v1, ECDSA-SHA256, with complex SAN)
my $ec_san_cert = '-----BEGIN CERTIFICATE-----
MIIB6jCCAZGgAwIBAgIUAzOGaDL9MVh6C+YChqwrQmKDm04wCgYIKoZIzj0EAwIw
HjEcMBoGA1UEAwwTRXhhbXBsZSBjZXJ0aWZpY2F0ZTAeFw0yMDA0MTcxMzI5Mjda
Fw0yMDA1MTcxMzI5MjdaMB4xHDAaBgNVBAMME0V4YW1wbGUgY2VydGlmaWNhdGUw
WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARt47IstyihcXvZgJpyO7UzDkP73z6l
6MFwznfFSN0aFCnxYWWWJqlu7eV/weKsS9oG/K136U2YoaXBqHQ4fETno4GsMIGp
MIGmBgNVHREEgZ4wgZukXTBbMQswCQYDVQQGEwJVUzEuMA0GA1UECgwGQmFyT3Jn
MA0GA1UECgwGRm9vT3JnMA4GA1UECwwHQmF6VW5pdDEcMBoGA1UEAwwTRXhhbXBs
ZSBjb21tb24gbmFtZYIPZG5zLmV4YW1wbGUuY29tgRFlbWFpbEBleGFtcGxlLmNv
bYcE20F1jocQcEYrOeMjiycv73JsEZeafjAKBggqhkjOPQQDAgNHADBEAiB8nyFx
/o3yY6GTMjGu3PpSaPS6J+6IvsprqR7ELWvJIQIgAZgxJuOg1egVzArsxWBMATbt
40ogDLlti/K+xBB886Y=
-----END CERTIFICATE-----';

# RSA-2048 certificate with KeyUsage, EKU, CRL DP, SAN
my $rsa_cert = '-----BEGIN CERTIFICATE-----
MIID0zCCArugAwIBAgIUUDCP+crnwwHYi3i6l/QQRgrMvMMwDQYJKoZIhvcNAQEL
BQAwMzERMA8GA1UEAwwIUlNBIFRlc3QxETAPBgNVBAoMCFRlc3QgT3JnMQswCQYD
VQQGEwJERTAeFw0yNjA2MDQxMDM0MTlaFw0zNjA2MDExMDM0MTlaMDMxETAPBgNV
BAMMCFJTQSBUZXN0MREwDwYDVQQKDAhUZXN0IE9yZzELMAkGA1UEBhMCREUwggEi
MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDoCmHyBiwymMTryASK2tDgykg7
hituJPcTmDiuikplUyohfuFuzUOYbudH+bAQRUUZ0njmJLYgcYGJI5qv+PQZfIRF
+JtG30nMuYwaNTWNyu2BvqLV4M6esWNHzlpV0xFsunH7RWRNUetdAmWJYWROogmQ
Ifi2Z3C89R6rCk4B9BPnlKUb/uNOITuTPxPMfmkpWesYcFbXbJA+ncbUsCQVzkNs
Z8LS/29FuSlINMmJZ+IuYXCKBTDRkwU45Ssl1a2JMSirVP1034RCMRmSWcQqgr4B
n0PuCMRsEfv1vRIa6PLazPG/VMeis5gpxH2846eD0aGLs2+IohcJheNpWIvzAgMB
AAGjgd4wgdswHQYDVR0OBBYEFHPcUxbjDRrK/JlTdf6m22AZ5x/zMB8GA1UdIwQY
MBaAFHPcUxbjDRrK/JlTdf6m22AZ5x/zMA4GA1UdDwEB/wQEAwIFoDAdBgNVHSUE
FjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDAYDVR0TAQH/BAIwADArBgNVHREEJDAi
gg9yc2EuZXhhbXBsZS5jb22BD3JzYUBleGFtcGxlLmNvbTAvBgNVHR8EKDAmMCSg
IqAghh5odHRwOi8vY3JsLmV4YW1wbGUuY29tL3JzYS5jcmwwDQYJKoZIhvcNAQEL
BQADggEBALvgqx9w1iYdbrNpb0V+KdgxZj5eeF50KLxZprsyYsFNLlGdUSTN+YaB
qt8s0MngMnyEb5MKg61G9wVyB5rYMQA5mcZlQoVG5QSIYdYMyLOmtzNYla+/NECz
VPyWW7+Ij9PE+8L58fF/R4baNlm7PM2rlQMU4huvZJce3h/QlmqbKq9LfBYmfPl+
z4Gw39oOTvvmIDcEwPhK5udGrSIOcU9NYHrE046mPYkhzMbgNwmMzEtw9BdIAEnX
aJ+GvzpQ+RydBjxXWP28Tb6FrqV2/lhmFwK/PqCX8Y1ZWvRF1X3Tg0B9XhtVx03C
364MRoD2K+hI2UGqCP13wyel8cJ9jQM=
-----END CERTIFICATE-----';

# RSA-PSS-2048 certificate (rsassaPss key + signature, SHA-256, saltlen=32)
my $rsapss_cert = '-----BEGIN CERTIFICATE-----
MIIEEDCCAsSgAwIBAgIUDn4yyQdSOA95on0cVCc51qEvXDIwQQYJKoZIhvcNAQEK
MDSgDzANBglghkgBZQMEAgEFAKEcMBoGCSqGSIb3DQEBCDANBglghkgBZQMEAgEF
AKIDAgEgMDYxFDASBgNVBAMMC1JTQVBTUyBUZXN0MREwDwYDVQQKDAhUZXN0IE9y
ZzELMAkGA1UEBhMCREUwHhcNMjYwNjA0MTAzNDUwWhcNMzYwNjAxMTAzNDUwWjA2
MRQwEgYDVQQDDAtSU0FQU1MgVGVzdDERMA8GA1UECgwIVGVzdCBPcmcxCzAJBgNV
BAYTAkRFMIIBUTA8BgkqhkiG9w0BAQowL6APMA0GCWCGSAFlAwQCAQUAoRwwGgYJ
KoZIhvcNAQEIMA0GCWCGSAFlAwQCAQUAA4IBDwAwggEKAoIBAQC9nAXHSFsdZN9i
6WD9T1/ciMmLAwJK6oHiuMrFN+SxUsonsT4ve1O2JWnF4ZSYPILRvBBq3a24KcvN
W2a4EdlWLXw1+++jB1KujVyXsbn9PciUfTT/lq+qOXCSPnKFX6l+NZ82WrFksdTK
FiYI6TBkeDlkzPRu2B2f4vU1p2lYf47MGBC6GDGFR8Sr2lV68bVEdlSm6FDmj5fc
Yk3k0345qg5ZCqSb+02SatGtinhC89ZSD/rsWS4l7daUGi/gNgLDbmhpMROD5ARa
DmUgFozqMnFSNClVNDwL4+xI+/LEo4UpFoz37IpRy4qOUzDolPlF0ZSlWvs8tbMS
kB48fT3vAgMBAAGjfzB9MB0GA1UdDgQWBBRW2GWqUvTjYjYRCXCHDrUgq9jAEjAf
BgNVHSMEGDAWgBRW2GWqUvTjYjYRCXCHDrUgq9jAEjAOBgNVHQ8BAf8EBAMCB4Aw
DAYDVR0TAQH/BAIwADAdBgNVHREEFjAUghJyc2Fwc3MuZXhhbXBsZS5jb20wQQYJ
KoZIhvcNAQEKMDSgDzANBglghkgBZQMEAgEFAKEcMBoGCSqGSIb3DQEBCDANBglg
hkgBZQMEAgEFAKIDAgEgA4IBAQBL4wZUnLDjx8JbVptDmRZ9AJ88wKVMymtGMwRH
Rdad+xPA7UOvSVt4NCkiUtCfW6Ukbk5ju7YiUbh7ptlyq2BDkvOkjLz2841d3IvG
vjT583xOWXRxsjF1x7AI6H66lVy3BYGrjfyWL82/quR6e3Oz+jQ+xB8NJcxhgJcO
6hnha1C7nWPbpITlJnZ8rtBw6lUDu4IayzEXYhTfqv3/t8jgBFuLdcpxdJzjf9LU
2FtmlOKkzkBe2+vX0g7tsTGMTQhxkdlya3/Y191l8SBeYJTl/PWjLOh0X0KmbweN
o4yZWGD+jT+XO4Tr2C91h+UqERgtnJOAkwSvCjSEuCw1mQln
-----END CERTIFICATE-----';

# EC P-256 certificate (ECDSA-SHA256, DNS + IP SAN)
my $ec_cert = '-----BEGIN CERTIFICATE-----
MIIB/jCCAaSgAwIBAgIUcfv/cVKLiRpWRPkkPLNWwrJMGEowCgYIKoZIzj0EAwIw
MjEQMA4GA1UEAwwHRUMgVGVzdDERMA8GA1UECgwIVGVzdCBPcmcxCzAJBgNVBAYT
AkRFMB4XDTI2MDYwNDEwMzQ1MFoXDTM2MDYwMTEwMzQ1MFowMjEQMA4GA1UEAwwH
RUMgVGVzdDERMA8GA1UECgwIVGVzdCBPcmcxCzAJBgNVBAYTAkRFMFkwEwYHKoZI
zj0CAQYIKoZIzj0DAQcDQgAEVuPtp2FDyVkki5o+PfCmwJBrNlhyp5NwyJh1cwna
xfSqQNaxd4wAYSX+FRzariPOBkDukiglKXW1kDtbWVvX+qOBlzCBlDAdBgNVHQ4E
FgQUMgz3IacdPhnA039mL8h81T7jJ9EwHwYDVR0jBBgwFoAUMgz3IacdPhnA039m
L8h81T7jJ9EwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMBMAwG
A1UdEwEB/wQCMAAwHwYDVR0RBBgwFoIOZWMuZXhhbXBsZS5jb22HBMAAAgEwCgYI
KoZIzj0EAwIDSAAwRQIgfbl1CSBrr49XVtsRJM1EKnn1c3MKpDIgc0yOtb/ibDUC
IQDN+YX5vQhfkxZyzY2Bt5x4h1gGyE5VurFIq+36L1Eslg==
-----END CERTIFICATE-----';

# RSA CA certificate (keyCertSign + cRLSign, BasicConstraints CA:true)
my $ca_cert = '-----BEGIN CERTIFICATE-----
MIIDVTCCAj2gAwIBAgIUGH9ivGcIsj8Xl//ZhyMz4TKIsw0wDQYJKoZIhvcNAQEL
BQAwMjEQMA4GA1UEAwwHVGVzdCBDQTERMA8GA1UECgwIVGVzdCBPcmcxCzAJBgNV
BAYTAkRFMB4XDTI2MDYwNDEwMzQ1NloXDTM2MDYwMTEwMzQ1NlowMjEQMA4GA1UE
AwwHVGVzdCBDQTERMA8GA1UECgwIVGVzdCBPcmcxCzAJBgNVBAYTAkRFMIIBIjAN
BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoHUr5S2h/OGHZHS5Lqp6VDl4eO/W
IluMMVDL2riEEKEN2XLmv6p07PIZF5f2PrtqJ27TmDrXWuKPtDg56/NqvfonwFZg
jvO4vDocNRTX2ZwvJDSHKnh/Cied+UICXpQHv7XMPN7hlWofvGEExtS2wZbjkGBK
1TZkBqrJQIuPAGnluWiIAjgy5NodvjuXh7E2IAhu05XXaGa2YzgbYvBYjgl51UcD
XCKKCHrB1AdV8TCbklAXYXErBi7O32LwsAWOCCqihFDyTLECpfM+16zKEBdkrgya
Jq6PBjfrBX9MrtMY3YmXGE/WPlFz45hN/+lgsYmSDrmtobDA+/yT/CYy3QIDAQAB
o2MwYTAdBgNVHQ4EFgQUQtwymCPKR/X76YXUPyOKvAzoEjQwHwYDVR0jBBgwFoAU
QtwymCPKR/X76YXUPyOKvAzoEjQwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQF
MAMBAf8wDQYJKoZIhvcNAQELBQADggEBAFnKmN2dQt2VqNsiAbdBhqHp0RxyTwsQ
Vbv0W/0M98IxnzmqdA3gpjz8v8FADPwL8iu/wYAsCizSkXGGxc7ZzODB7wBdPSbi
70nXtP3Im3pKgE4W8L039tkXId23jZSMiHg55GhMZ7tSpBRhIdh0HjKwK/AhbU60
nzfpDNmaYqPnCwbxczOTm1BBNfCdgvx486upslu09Q+Hu4ajQoYvjB10ImilkOvD
vbXpZCfp57xJs6VUTREUvmz6/r8fodcw0CLmLWmow6vrUnZRT1iqEDqf2to4YNs3
+utxlrVV1zvd+Uzfa5P55ZKFHtueXCo6Nm3ZcJyKkVG2WbRcjwNEI8A=
-----END CERTIFICATE-----';

# -------------------------------------------------------------------------
# Original SAN test (backward-compat)
# -------------------------------------------------------------------------
subtest 'original EC cert (complex SAN)' => sub {
    my $x509 = OpenXPKI::Crypt::X509->new($ec_san_cert);
    ok($x509, 'certificate parsed');
    is($x509->pem, $ec_san_cert, 'pem round-trips unchanged');
    is($x509->get_subject, 'CN=Example certificate', 'subject');
    is_deeply($x509->get_subject_alt_name,
        [
            [
                'dirName',
                {
                    rdnSequence => [
                        [{ value => { printableString => 'US' }, type => '2.5.4.6' }],
                        [
                            { value => { utf8String => 'BarOrg' }, type => '2.5.4.10' },
                            { type  => '2.5.4.10', value => { utf8String => 'FooOrg' } },
                            { type  => '2.5.4.11', value => { utf8String => 'BazUnit' } },
                        ],
                        [{ type => '2.5.4.3', value => { utf8String => 'Example common name' } }],
                    ]
                }
            ],
            [ 'DNS',   'dns.example.com' ],
            [ 'email', 'email@example.com' ],
            [ 'IP',    '219.65.117.142' ],
            [ 'IP',    '7046:2B39:E323:8B27:2FEF:726C:1197:9A7E' ],
        ],
        'SAN (dirName + DNS + email + IPv4 + IPv6)');
    is($x509->notbefore, 1587130167, 'notbefore epoch');
    is($x509->notafter,  1589722167, 'notafter epoch');
    is($x509->get_serial, '18276018821053647745944141854221156918868810574', 'serial');
};

# -------------------------------------------------------------------------
# RSA-2048 certificate – comprehensive accessor coverage
# -------------------------------------------------------------------------
subtest 'RSA-2048 certificate' => sub {
    my $x = OpenXPKI::Crypt::X509->new($rsa_cert);
    ok($x, 'parsed');

    # Identity / encoding
    like($x->pem, qr/^-----BEGIN CERTIFICATE-----/, 'pem starts with PEM header');
    is($x->get_identifier,      '6HdXsPgJalh1WMXN1bgQn5PCV0U', 'identifier');
    is($x->get_cert_identifier, '6HdXsPgJalh1WMXN1bgQn5PCV0U', 'cert_identifier alias');

    # DN
    is($x->get_subject, 'C=DE,O=Test Org,CN=RSA Test', 'subject');
    is($x->get_issuer,  'C=DE,O=Test Org,CN=RSA Test', 'issuer (self-signed)');
    is_deeply($x->subject_hash, { CN => ['RSA Test'], O => ['Test Org'], C => ['DE'] }, 'subject_hash');
    is($x->cn, 'RSA Test', 'cn');
    ok(ref($x->get_issuer_rdn) eq 'ARRAY', 'get_issuer_rdn returns arrayref');

    # Validity
    is($x->notbefore, 1780569259, 'notbefore epoch');
    is($x->notafter,  2095929259, 'notafter epoch');
    is($x->get_notbefore('epoch'), 1780569259, 'get_notbefore(epoch)');
    is($x->get_notafter('epoch'),  2095929259, 'get_notafter(epoch)');
    isa_ok($x->get_notbefore(), 'DateTime', 'get_notbefore() returns DateTime');

    # Serial
    is($x->get_serial, '457802239492341667817385893333946960666258357443', 'serial');

    # Key identifiers
    is($x->get_subject_key_id,   '73:DC:53:16:E3:0D:1A:CA:FC:99:53:75:FE:A6:DB:60:19:E7:1F:F3', 'SKI');
    is($x->get_authority_key_id, '73:DC:53:16:E3:0D:1A:CA:FC:99:53:75:FE:A6:DB:60:19:E7:1F:F3', 'AKI');
    is($x->get_public_key_hash,  '73:DC:53:16:E3:0D:1A:CA:FC:99:53:75:FE:A6:DB:60:19:E7:1F:F3', 'public_key_hash');

    # Public key
    is($x->get_public_key_alg,             'RSA',  'key algorithm');
    is($x->get_key_params->{key_length},   2048,   'key length 2048');
    ok(length($x->get_pub_key) > 0,                'get_pub_key returns bytes');
    ok(length($x->get_spki_der) > 0,               'get_spki_der returns bytes');

    # Signature
    is($x->get_signature_digest, 'sha256', 'signature digest');
    is($x->check_signature, 1, 'signature valid');

    # Extensions – KeyUsage
    my $ku = $x->get_key_usage;
    ok($ku, 'KeyUsage present');
    ok($ku->critical, 'KeyUsage is critical');
    ok((grep { $_ eq 'digitalSignature' } @{$ku->bits}), 'KeyUsage: digitalSignature');
    ok((grep { $_ eq 'keyEncipherment'  } @{$ku->bits}), 'KeyUsage: keyEncipherment');

    # Extensions – ExtendedKeyUsage
    my $eku = $x->get_ext_key_usage;
    ok($eku, 'EKU present');
    ok((grep { $_ eq 'serverAuth' } @{$eku->usages}), 'EKU: serverAuth');
    ok((grep { $_ eq 'clientAuth' } @{$eku->usages}), 'EKU: clientAuth');

    # Extensions – BasicConstraints
    my $bc = $x->get_basic_constraints;
    ok($bc, 'BasicConstraints present');
    is($bc->ca, 0, 'BasicConstraints: not CA');
    ok($bc->critical, 'BasicConstraints: critical');

    # Extensions – CRL Distribution Points
    is_deeply($x->get_cdp, ['http://crl.example.com/rsa.crl'], 'CRL DP');

    # Extensions – AIA (not present in this cert)
    is_deeply($x->get_authority_info, { caIssuer => [], ocsp => [] }, 'AIA empty');

    # SAN
    my $san = $x->get_subject_alt_name;
    is(scalar @$san, 2, 'two SAN entries');
    is_deeply($san->[0], ['DNS',   'rsa.example.com'],  'SAN DNS');
    is_deeply($san->[1], ['email', 'rsa@example.com'],  'SAN email');

    # cert_subject_parts merges DN + SAN
    my $parts = $x->get_cert_subject_parts;
    is_deeply($parts->{CN},        ['RSA Test'],          'subject_parts CN');
    is_deeply($parts->{SAN_DNS},   ['rsa.example.com'],   'subject_parts SAN_DNS');
    is_deeply($parts->{SAN_EMAIL}, ['rsa@example.com'],   'subject_parts SAN_EMAIL');

    # extensions OID map
    my $exts = $x->extensions;
    ok(exists $exts->{'2.5.29.15'}, 'extensions map has KeyUsage OID');
    ok(exists $exts->{'2.5.29.17'}, 'extensions map has SAN OID');

    # get_extension_value by OID returns raw DER
    my $ku_der = $x->get_extension_value('2.5.29.15');
    ok(defined $ku_der && length($ku_der) > 0, 'get_extension_value by OID returns DER');

    # Self-signed / CA flags
    is($x->is_selfsigned, 1, 'is_selfsigned');
    is($x->is_ca,         0, 'is_ca false');

    # No custom/PEN extensions
    is_deeply($x->get_custom_extension,    [], 'no custom extensions');
    is_deeply($x->get_cert_extension_parts, {}, 'no cert extension parts');

    # db_hash structure
    my $db = $x->db_hash;
    is($db->{cert_key},  '457802239492341667817385893333946960666258357443', 'db_hash cert_key');
    is($db->{identifier}, '6HdXsPgJalh1WMXN1bgQn5PCV0U', 'db_hash identifier');
    is($db->{subject},    'C=DE,O=Test Org,CN=RSA Test',  'db_hash subject');
    is($db->{issuer_dn},  'C=DE,O=Test Org,CN=RSA Test',  'db_hash issuer_dn');
    is($db->{notbefore},  1780569259, 'db_hash notbefore');
    is($db->{notafter},   2095929259, 'db_hash notafter');
};

# -------------------------------------------------------------------------
# RSA-PSS-2048 certificate – key type and PSS signature
# -------------------------------------------------------------------------
subtest 'RSA-PSS-2048 certificate' => sub {
    my $x = OpenXPKI::Crypt::X509->new($rsapss_cert);
    ok($x, 'parsed');

    # Identity
    is($x->get_identifier, 'Jc56LTt_UJ4nIIy3vEiDgz2nC0E', 'identifier');
    is($x->get_subject, 'C=DE,O=Test Org,CN=RSAPSS Test', 'subject');
    is($x->get_serial, '82740188707332452329959634297714991704681962546', 'serial');
    is($x->notbefore,  1780569290, 'notbefore');
    is($x->get_subject_key_id, '56:D8:65:AA:52:F4:E3:62:36:11:09:70:87:0E:B5:20:AB:D8:C0:12', 'SKI');

    # Key
    is($x->get_public_key_alg,           'RSA',  'key algorithm RSA (PSS)');
    is($x->get_key_params->{key_length}, 2048,   'key length 2048');
    ok(!defined $x->get_key_params->{curve_name}, 'no curve_name for RSA');
    ok(length($x->get_pub_key)    > 0,  'get_pub_key non-empty');
    ok(length($x->get_spki_der)   > 0,  'get_spki_der non-empty');
    is($x->get_public_key_hash, '56:D8:65:AA:52:F4:E3:62:36:11:09:70:87:0E:B5:20:AB:D8:C0:12', 'public_key_hash');

    # Signature
    is($x->get_signature_digest, 'pss', 'signature digest is pss');
    is($x->check_signature, 1, 'PSS signature valid');

    # Extensions
    my $ku = $x->get_key_usage;
    ok($ku,         'KeyUsage present');
    ok($ku->critical, 'KeyUsage critical');
    is_deeply($ku->bits, ['digitalSignature'], 'KeyUsage bits');

    is($x->get_ext_key_usage, undef, 'no EKU');

    my $bc = $x->get_basic_constraints;
    ok($bc, 'BasicConstraints present');
    is($bc->ca, 0, 'not CA');

    is_deeply($x->get_subject_alt_name, [['DNS', 'rsapss.example.com']], 'SAN DNS');

    is($x->is_selfsigned, 1, 'is_selfsigned');
    is($x->is_ca,         0, 'is_ca false');
};

# -------------------------------------------------------------------------
# EC P-256 certificate – EC-specific key params
# -------------------------------------------------------------------------
subtest 'EC P-256 certificate' => sub {
    my $x = OpenXPKI::Crypt::X509->new($ec_cert);
    ok($x, 'parsed');

    # Identity
    is($x->get_identifier, '0ThPAbFU5Jmj75iUAmRDlo24aIk', 'identifier');
    is($x->get_subject, 'C=DE,O=Test Org,CN=EC Test', 'subject');
    is($x->get_serial, '650735696342466319270258446539589529086708160586', 'serial');
    is($x->notbefore,  1780569290, 'notbefore');
    is($x->get_subject_key_id, '32:0C:F7:21:A7:1D:3E:19:C0:D3:7F:66:2F:C8:7C:D5:3E:E3:27:D1', 'SKI');

    # EC key
    is($x->get_public_key_alg,              'EC',          'key algorithm EC');
    is($x->get_key_params->{key_length},    256,           'key length 256');
    is($x->get_key_params->{curve_name},    'prime256v1',  'curve prime256v1');
    ok(length($x->get_pub_key)  > 0, 'get_pub_key non-empty');
    ok(length($x->get_spki_der) > 0, 'get_spki_der non-empty');
    is($x->get_public_key_hash, '32:0C:F7:21:A7:1D:3E:19:C0:D3:7F:66:2F:C8:7C:D5:3E:E3:27:D1', 'public_key_hash');

    # Signature
    is($x->get_signature_digest, 'sha256', 'signature digest sha256');
    is($x->check_signature, 1, 'ECDSA signature valid');

    # Extensions – KeyUsage
    my $ku = $x->get_key_usage;
    ok($ku, 'KeyUsage present');
    ok($ku->critical, 'KeyUsage critical');
    is_deeply($ku->bits, ['digitalSignature'], 'KeyUsage: digitalSignature only');

    # Extensions – EKU
    my $eku = $x->get_ext_key_usage;
    ok($eku, 'EKU present');
    is_deeply($eku->usages, ['serverAuth'], 'EKU: serverAuth');

    # Extensions – BasicConstraints
    my $bc = $x->get_basic_constraints;
    ok($bc, 'BasicConstraints present');
    is($bc->ca, 0, 'not CA');

    # SAN: DNS + IPv4
    my $san = $x->get_subject_alt_name;
    is(scalar @$san, 2, 'two SAN entries');
    is_deeply($san->[0], ['DNS', 'ec.example.com'], 'SAN DNS');
    is_deeply($san->[1], ['IP',  '192.0.2.1'],      'SAN IPv4');

    is($x->is_selfsigned, 1, 'is_selfsigned');
    is($x->is_ca,         0, 'is_ca false');

    # db_hash
    my $db = $x->db_hash;
    is($db->{subject},   'C=DE,O=Test Org,CN=EC Test', 'db_hash subject');
    is($db->{notbefore}, 1780569290, 'db_hash notbefore');
};

# -------------------------------------------------------------------------
# RSA CA certificate – is_ca / is_selfsigned / keyCertSign
# -------------------------------------------------------------------------
subtest 'RSA CA certificate' => sub {
    my $x = OpenXPKI::Crypt::X509->new($ca_cert);
    ok($x, 'parsed');

    is($x->get_identifier, 'u8wkj3VDxh7G1eaeh2tkT-H0T8E', 'identifier');
    is($x->get_subject, 'C=DE,O=Test Org,CN=Test CA', 'subject');
    is($x->get_serial, '139856574254047468569473202711251447762989396749', 'serial');
    is($x->notbefore,  1780569296, 'notbefore');
    is($x->get_subject_key_id, '42:DC:32:98:23:CA:47:F5:FB:E9:85:D4:3F:23:8A:BC:0C:E8:12:34', 'SKI');

    # Key
    is($x->get_public_key_alg,           'RSA', 'key algorithm RSA');
    is($x->get_key_params->{key_length}, 2048,  'key length 2048');
    is($x->get_signature_digest,         'sha256', 'sig digest sha256');
    is($x->check_signature, 1, 'signature valid');

    # KeyUsage must include keyCertSign for is_ca to return true
    my $ku = $x->get_key_usage;
    ok($ku, 'KeyUsage present');
    ok((grep { $_ eq 'keyCertSign' } @{$ku->bits}), 'keyCertSign set');
    ok((grep { $_ eq 'cRLSign'     } @{$ku->bits}), 'cRLSign set');

    # BasicConstraints CA:true + critical
    my $bc = $x->get_basic_constraints;
    ok($bc, 'BasicConstraints present');
    is($bc->ca, 1, 'BasicConstraints CA:true');
    ok($bc->critical, 'BasicConstraints critical');

    is($x->is_selfsigned, 1, 'is_selfsigned');
    is($x->is_ca,         1, 'is_ca true');

    is($x->get_ext_key_usage, undef, 'no EKU on CA');
};

done_testing;

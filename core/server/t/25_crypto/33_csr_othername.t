use strict;
use warnings;
use Test::More;
use Test::Exception;

BEGIN { use_ok "OpenXPKI::Crypt::PKCS10" }

# EC P-256 CSR with a DNS name and an IEEE 802.1AR style otherName of type
# id-on-hardwareModuleName (RFC 4108 section 5): SEQUENCE { hwType OID, hwSerialNum OCTET STRING }
my $hwmod_csr = '-----BEGIN CERTIFICATE REQUEST-----
MIIBNDCB2wIBADAnMRAwDgYDVQQKDAdFeGFtcGxlMRMwEQYDVQQDDApkZXZpZC10
ZXN0MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAElBldVqsT9buNROAYR5r2Gvzj
1sBqOUQroZayTvdZhFfEttZfMP8oZy4X/b0roorcMw1M/RhwfsWsnmnpa9VF1qBS
MFAGCSqGSIb3DQEJDjFDMEEwPwYDVR0RBDgwNoIRZGV2aWQuZXhhbXBsZS5jb22g
IQYIKwYBBQUHCASgFTATBgorBgEEAYaNHwECBAUBAqvN7zAKBggqhkjOPQQDAgNI
ADBFAiEA7w1OUanhjYFfHQ+lnUeDpdaNUo7lHYPtD+S6acWmpWECIByYh2wZZ7JG
+/uzREl0pw2IYZ1j7HGhJWrXfo0ydPK0
-----END CERTIFICATE REQUEST-----';

# same type OID, but the value is a UTF8String instead of the SEQUENCE: not a HardwareModuleName
my $hwmod_malformed_csr = '-----BEGIN CERTIFICATE REQUEST-----
MIIBGzCBwgIBADAmMRAwDgYDVQQKDAdFeGFtcGxlMRIwEAYDVQQDDAlkZXZpZC1i
YWQwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAASUGV1WqxP1u41E4BhHmvYa/OPW
wGo5RCuhlrJO91mEV8S21l8w/yhnLhf9vSuiitwzDUz9GHB+xayeaelr1UXWoDow
OAYJKoZIhvcNAQkOMSswKTAnBgNVHREEIDAeoBwGCCsGAQUFBwgEoBAMDm5vdC1h
LXNlcXVlbmNlMAoGCCqGSM49BAMCA0gAMEUCIH+3UoSekLpemH6SziFXw+kkFVjp
HzzgToXmA/3WVNc0AiEA9mOQsMOSIkt2P42HxORk5qHQMqBS06dr97ly5oSvJpA=
-----END CERTIFICATE REQUEST-----';

subtest 'otherName hardwareModuleName (RFC 4108, IEEE 802.1AR)' => sub {
    my $x = OpenXPKI::Crypt::PKCS10->new($hwmod_csr);
    ok($x, 'parsed');
    is($x->get_subject, 'CN=devid-test,O=Example', 'subject');

    my $san;
    lives_ok { $san = $x->get_subject_alt_name } 'SAN with hardwareModuleName decodes';
    is(scalar @$san, 2, 'two SAN entries');
    is_deeply($san->[0], ['DNS', 'devid.example.com'], 'SAN DNS');
    is_deeply($san->[1],
        ['otherName', '1.3.6.1.5.5.7.8.4;hwType=1.3.6.1.4.1.99999.1.2;hwSerialNum=0102abcdef'],
        'hardwareModuleName rendered as type;hwType;hwSerialNum');

    my $parts = $x->get_cert_subject_parts;
    is_deeply($parts->{SAN_DNS}, ['devid.example.com'], 'subject_parts SAN_DNS');
    is_deeply($parts->{SAN_OTHERNAME},
        ['1.3.6.1.5.5.7.8.4;hwType=1.3.6.1.4.1.99999.1.2;hwSerialNum=0102abcdef'],
        'subject_parts SAN_OTHERNAME');
};

subtest 'otherName with hardwareModuleName OID but a string value is refused' => sub {
    my $x = OpenXPKI::Crypt::PKCS10->new($hwmod_malformed_csr);
    ok($x, 'parsed');
    throws_ok { $x->get_subject_alt_name } qr/Failed to decode HardwareModuleName otherName/,
        'malformed hardwareModuleName throws';
};

done_testing;

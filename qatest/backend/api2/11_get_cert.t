#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempfile );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 10;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows WorkflowCreateCert )],
);

# Create certificate
my $cert_info = $oxitest->create_cert(
    hostname => "127.0.0.1",
);
my $cert_id = $cert_info->{identifier};

#
# Tests
#

# Fetch certificate - HASH Format
my ($serial, $serial_f);

lives_and {
    my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'HASH' });
    cmp_deeply($result, superhashof({
        'BODY' => superhashof({
            'ALIAS'               => ignore(),              # might be undef
            'CA_ISSUER_NAME'      => re(qr/^.+$/),          # 'CN=Root CA,OU=Test CA,DC=OpenXPKI,DC=ORG',
            'CA_ISSUER_SERIAL'    => re(qr/^(0|1)$/),       # '1',
            'CA_KEYID'            => re(qr/^.+$/),          # '9A:1D:9E:0A:03:95:91:26:5C:42:5F:90:0C:2E:02:C1:6B:29:14:5C',
            'EMAILADDRESS'        => ignore(),              # might be undef
            'EXPONENT'            => re(qr/\d+$/),          # '10001',
            'EXTENSIONS'          => superhashof({}),       # HashRef
            'FINGERPRINT'         => re(qr/^.+$/),          # 'SHA1:94:28:74:12:AA:3E:01:A6:DB:C2:BD:78:A4:95:12:2C:FA:33:EA:38'
            'IS_CA'               => re(qr/^(0|1)$/),       # '0',
            'ISSUER'              => re(qr/^.+$/),          # 'CN=CA ONE,OU=Test CA,DC=OpenXPKI,DC=ORG',
            'KEYID'               => re(qr/^.+$/),          # '94:FA:0B:95:AA:46:3B:7E:1B:F2:AB:67:3A:2D:ED:7B:85:6B:C8:27',
            'KEYSIZE'             => re(qr/\d+$/),          # '2048',
            'MODULUS'             => re(qr/^.+$/),
            'NOTAFTER'            => re(qr/\d+$/),          # '1496085427',
            'NOTBEFORE'           => re(qr/\d+$/),          # '1480447027',
            'PLAIN_EXTENSIONS'    => re(qr/^.+$/m),         # multiline
            'PUBKEY_ALGORITHM'    => re(qr/^.+$/),          # 'rsaEncryption',
            'PUBKEY_HASH'         => re(qr/^.+$/),          # 'SHA1:94:FA:0B:95:AA:46:3B:7E:1B:F2:AB:67:3A:2D:ED:7B:85:6B:C8:27',
            'PUBKEY'              => re(qr/^.+$/m),         # multiline
            'SERIAL_HEX'          => re(qr/^[a-f0-9]+$/i),  # '8c9e25459b3ebfb5daff',
            'SERIAL'              => re(qr/\d+$/),          # '664048578888843042085631',
            'SIGNATURE_ALGORITHM' => re(qr/^.+$/),          # 'sha256WithRSAEncryption',
            'SUBJECT_HASH'        => {
                'CN' => array_each(re(qr/^.+$/)),
                'DC' => array_each(re(qr/^.+$/)),
            },
            'SUBJECT'             => re(qr/^.+$/),          # 'CN=nicetest-917e91.openxpki.test:8080,DC=Test Deployment,DC=OpenXPKI,DC=org',
            'VERSION'             => re(qr/^.+$/),          # '3 (0x2)',
        }),
        'CSR_SERIAL'        => re(qr/\d+$/),                # '36095'
        'HEADER'            => superhashof({}),             # HashRef,
        'IDENTIFIER'        => re(qr/^.+$/),                # 'lCh0Eqo-Aabbwr14pJUSLPoz6jg'
        'ISSUER_IDENTIFIER' => re(qr/^.+$/),                # 'k1izCpwZwEu6jFJZbwul-fVoQFY',
        'PKI_REALM'         => re(qr/^.+$/),                # 'ca-one',
        'STATUS'            => re(qr/^\w+$/),               # 'ISSUED'
    }), "HASH contains relevant elements");

    $serial = uc($result->{BODY}->{SERIAL_HEX});
    $serial = "0$serial" if length($serial) % 2 == 1; # prepend 0 if uneven amount of hex digits
    $serial_f = join ":", unpack("(A2)*", $serial);
    note "Certificate serial: $serial_f";
} "Fetch certificate (HASH)";

# Fetch certificate - PEM Format
my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
my $pem;
lives_and {
    $pem = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'PEM' });
    print $tmp $pem;
    close $tmp;
    my $cmp_serial = `OPENSSL_CONF=/dev/null openssl x509 -in $tmp_name -inform PEM -serial`;
    like $cmp_serial, qr/$serial/i;
} "Fetch certificate (PEM)";

# Fetch certificate - DER Format
($tmp, $tmp_name) = tempfile(UNLINK => 1);
lives_and {
    my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'DER' });
    print $tmp $result;
    close $tmp;
    my $cmp_serial = `OPENSSL_CONF=/dev/null openssl x509 -in $tmp_name -inform DER -serial`;
    like $cmp_serial, qr/$serial/i;
} "Fetch certificate (DER)";

## Compare PEM and DER
my $pem2 = `OPENSSL_CONF=/dev/null openssl x509 -in $tmp_name -inform DER`;
$pem =~ s{\s}{}gxms; $pem2 =~ s{\s}{}gxms; # Clear all whitespace to compare
is $pem, $pem2, 'DER matches PEM';

# Fetch certificate - TXT Format
TODO: {
    local $TODO = "TXT does not work (issue #185)";

    lives_and {
        my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'TXT' });
        like $result, qr/$serial_f/i;
    } "Fetch certificate (TXT)";
}

# Fetch certificate - DBINFO Format
my $dbinfo_serial;
lives_and {
    my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'DBINFO' });
    cmp_deeply $result, superhashof({
        'authority_key_identifier'  => re(qr/^([[:alnum:]]{2}:)+[[:alnum:]]{2}$/), # '9A:1D:9E:0A:03:95:91:26:5C:42:5F:90:0C:2E:02:C1:6B:29:14:5C',
        'cert_attributes' => {
            'meta_email'            => [ re(qr/^.+$/) ],        # [ 'andreas.anders@mycompany.local' ],
            'meta_entity'           => [ re(qr/^.+$/) ],        # [ 'nicetest-63a0ee.openxpki.test' ]
            'meta_requestor'        => [ re(qr/^.+$/) ],        # [ 'Andreas Anders' ],
            'subject_alt_name'      => array_each( re(qr/^.+$/) ),
            'system_cert_owner'     => [ re(qr/^\w+$/) ],       # [ 'user' ],
            'system_workflow_csr'   => [ re(qr/\d+$/) ],        # [ '129279' ],
        },
        'cert_key'                  => re(qr/\d+$/),            # '727900818024539824542719',
        'cert_key_hex'              => re(qr/^[a-f0-9]+$/i),    # '9a239519017fd5bb53ff',
        'req_key'                   => re(qr/\d+$/),            # '39679',
        'identifier'                => re(qr/^.+$/),            # 'oLhPSQTJAkc7KmtKW1fA9Te6aVk'
        'issuer_dn'                 => re(qr/^.+$/),            # 'CN=CA ONE,OU=Test CA,DC=OpenXPKI,DC=ORG',
        'issuer_identifier'         => re(qr/^.+$/),            # 'k1izCpwZwEu6jFJZbwul-fVoQFY',
        'notafter'                  => re(qr/\d+$/),            # '1496094413',
        'notbefore'                 => re(qr/\d+$/),            # '1480456013',
        'pki_realm'                 => re(qr/^.+$/),            # 'ca-one',
        'public_key'                => re(qr/^.+$/m),           # multiline
        'status'                    => re(qr/^\w+$/),           # 'ISSUED',
        'subject'                   => re(qr/^.+$/),            # 'CN=nicetest-63a0ee.openxpki.test:8080,DC=Test Deployment,DC=OpenXPKI,DC=org',
        'subject_key_identifier'    => re(qr/^.+$/),            # 'BD:B1:9B:63:70:40:A3:3D:48:2C:0C:7A:0D:33:90:2E:C0:D2:23:89',
    }), "DBINFO contains relevant elements";
    $dbinfo_serial = uc($result->{cert_key_hex});
    $dbinfo_serial = "0$dbinfo_serial" if length($dbinfo_serial) % 2 == 1; # prepend 0 if uneven amount of hex digits
    is $dbinfo_serial, $serial;
} "Fetch certificate (DBINFO)";

#
# get_cert_attributes
#
lives_and {
    my $result = $oxitest->api2_command("get_cert_attributes" => { identifier => $cert_id });
    cmp_deeply $result, {
        'meta_email'            => [ re(qr/^.+$/) ],        # [ 'andreas.anders@mycompany.local' ],
        'meta_entity'           => [ re(qr/^.+$/) ],        # [ 'nicetest-63a0ee.openxpki.test' ]
        'meta_requestor'        => [ re(qr/^.+$/) ],        # [ 'Andreas Anders' ],
        'subject_alt_name'      => array_each( re(qr/^.+$/) ),
        'system_cert_owner'     => [ re(qr/^\w+$/) ],       # [ 'user' ],
        'system_workflow_csr'   => [ re(qr/\d+$/) ],        # [ '129279' ],
    };
} "get_cert_attributes - retrieve all";

lives_and {
    my $result = $oxitest->api2_command("get_cert_attributes" => { identifier => $cert_id, attribute => "system_%" });
    cmp_deeply $result, {
        'system_cert_owner'     => [ re(qr/^\w+$/) ],       # [ 'user' ],
        'system_workflow_csr'   => [ re(qr/\d+$/) ],        # [ '129279' ],
    };
} "get_cert_attributes - retrieve filtered list";

#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;
use File::Temp qw( tempfile );

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use Test::More;
use Test::Deep;
use TestCfg;
use OpenXPKI::Test::CertHelper;

our %cfg = ();
my $testcfg = new TestCfg;
$testcfg->read_config_path( 'api.cfg', \%cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg{instance}{socketfile},
    realm => $cfg{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});
$test->plan( tests => 14 );

$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

# Create certificate
use DateTime;
my $cert_info = OpenXPKI::Test::CertHelper->via_workflow(
    tester => $test,
    hostname => "127.0.0.1",
);

# Fetch certificate - HASH Format
$test->runcmd_ok('get_cert', { IDENTIFIER => $cert_info->{identifier}, FORMAT => 'HASH' }, "Fetch certificate (HASH)");
my $params = $test->get_msg()->{PARAMS};

cmp_deeply($params, superhashof({
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

my $serial = uc($params->{BODY}->{SERIAL_HEX});
$serial = "0$serial" if length($serial) % 2 == 1; # prepend 0 if uneven amount of hex digits
my $serial_f = join ":", unpack("(A2)*", $serial);
note "Certificate serial: $serial_f";

# Fetch certificate - PEM Format
my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
$test->runcmd_ok('get_cert', { IDENTIFIER => $cert_info->{identifier}, FORMAT => 'PEM' }, 'Fetch certificate (PEM)');
my $pem = $test->get_msg()->{PARAMS};
print $tmp $pem;
close $tmp;
my $cmp_serial = `openssl x509 -in $tmp_name -inform PEM -serial`;
like $cmp_serial, qr/$serial/i, "PEM matches serial $cmp_serial";

# Fetch certificate - DER Format
$test->runcmd_ok('get_cert', { IDENTIFIER => $cert_info->{identifier}, FORMAT => 'DER' }, 'Fetch certificate (DER)');
($tmp, $tmp_name) = tempfile(UNLINK => 1);
print $tmp $test->get_msg()->{PARAMS};
close $tmp;
$cmp_serial = `openssl x509 -in $tmp_name -inform DER -serial`;
like $cmp_serial, qr/$serial/i, "DER matches serial";

# Compare PEM and DER
my $pem2 = `openssl x509 -in $tmp_name -inform DER`;
$pem =~ s{\s}{}gxms; $pem2 =~ s{\s}{}gxms; # Clear all whitespace to compare
$test->is( $pem, $pem2, 'DER matches PEM' );

# Fetch certificate - TXT Format
TODO: {
    local $TODO = "TXT does not work (issue #185)";

    ok scalar( $test->runcmd('get_cert', { IDENTIFIER => $cert_info->{identifier}, FORMAT => 'TXT' }) ), "Fetch certificate (TXT)";
    like $test->get_msg()->{PARAMS}, qr/$serial_f/i, "TXT matches serial";
}

# Fetch certificate - DBINFO Format
$test->runcmd_ok('get_cert', { IDENTIFIER => $cert_info->{identifier}, FORMAT => 'DBINFO' }, "Fetch certificate (DBINFO)");
$params = $test->get_msg()->{PARAMS};
cmp_deeply($params, superhashof({
    'AUTHORITY_KEY_IDENTIFIER'  => re(qr/^([[:alnum:]]{2}:)+[[:alnum:]]{2}$/), # '9A:1D:9E:0A:03:95:91:26:5C:42:5F:90:0C:2E:02:C1:6B:29:14:5C',
    'CERT_ATTRIBUTES' => {
        'meta_email'            => [ re(qr/^.+$/) ],        # [ 'andreas.anders@mycompany.local' ],
        'meta_entity'           => [ re(qr/^.+$/) ],        # [ 'nicetest-63a0ee.openxpki.test' ]
        'meta_requestor'        => [ re(qr/^.+$/) ],        # [ 'Andreas Anders' ],
        'subject_alt_name'      => array_each( re(qr/^.+$/) ),
        'system_cert_owner'     => [ re(qr/^\w+$/) ],       # [ 'user' ],
        'system_workflow_csr'   => [ re(qr/\d+$/) ],        # [ '129279' ],
    },
    'CERTIFICATE_SERIAL'        => re(qr/\d+$/),            # '727900818024539824542719',
    'CERTIFICATE_SERIAL_HEX'    => re(qr/^[a-f0-9]+$/i),    # '9a239519017fd5bb53ff',
    'CSR_SERIAL'                => re(qr/\d+$/),            # '39679',
    'IDENTIFIER'                => re(qr/^.+$/),            # 'oLhPSQTJAkc7KmtKW1fA9Te6aVk'
    'ISSUER_DN'                 => re(qr/^.+$/),            # 'CN=CA ONE,OU=Test CA,DC=OpenXPKI,DC=ORG',
    'ISSUER_IDENTIFIER'         => re(qr/^.+$/),            # 'k1izCpwZwEu6jFJZbwul-fVoQFY',
    'LOA'                       => ignore(),                # might be undef,
    'NOTAFTER'                  => re(qr/\d+$/),            # '1496094413',
    'NOTBEFORE'                 => re(qr/\d+$/),            # '1480456013',
    'PKI_REALM'                 => re(qr/^.+$/),            # 'ca-one',
    'PUBKEY'                    => re(qr/^.+$/m),           # multiline
    'STATUS'                    => re(qr/^\w+$/),           # 'ISSUED',
    'SUBJECT'                   => re(qr/^.+$/),            # 'CN=nicetest-63a0ee.openxpki.test:8080,DC=Test Deployment,DC=OpenXPKI,DC=org',
    'SUBJECT_KEY_IDENTIFIER'    => re(qr/^.+$/),            # 'BD:B1:9B:63:70:40:A3:3D:48:2C:0C:7A:0D:33:90:2E:C0:D2:23:89',
}), "DBINFO contains relevant elements");
my $dbinfo_serial = uc($params->{CERTIFICATE_SERIAL_HEX});
$dbinfo_serial = "0$dbinfo_serial" if length($dbinfo_serial) % 2 == 1; # prepend 0 if uneven amount of hex digits
$test->is($dbinfo_serial, $serial, "DBINFO matches serial");

$test->disconnect;

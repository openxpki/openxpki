#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Temp qw( tempfile );
use MIME::Base64;

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


plan tests => 11;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows WorkflowCreateCert )],
);
my $tempdir = $oxitest->testenv_root;

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
        serial_hex              => re(qr/^[a-f0-9]+$/i),  # '8c9e25459b3ebfb5daff',
        serial                  => re(qr/\d+$/),          # '664048578888843042085631',
        subject                 => re(qr/^.+$/),          # 'CN=nicetest-917e91.openxpki.test:8080,DC=Test Deployment,DC=OpenXPKI,DC=org',
        subject_hash => {
            'CN' => array_each(re(qr/^.+$/)),
            'DC' => array_each(re(qr/^.+$/)),
        },
        notbefore               => re(qr/\d+$/),          # '1496085427',
        notafter                => re(qr/\d+$/),          # '1496085427',
        status                  => "ISSUED",              # 'ISSUED'
        identifier              => re(qr/^.+$/),          # 'lCh0Eqo-Aabbwr14pJUSLPoz6jg'
        issuer_identifier       => re(qr/^.+$/),          # 'k1izCpwZwEu6jFJZbwul-fVoQFY',
        issuer                  => re(qr/^.+$/),          # 'CN=CA ONE,OU=Test CA,DC=OpenXPKI,DC=ORG',
        csr_serial              => re(qr/\d+$/),          # '36095'
        pki_realm               => re(qr/^.+$/),          # 'ca-one',
    }), "HASH contains relevant elements") or diag explain $result;

    $serial = uc($result->{serial_hex});
    $serial = "0$serial" if length($serial) % 2 == 1; # prepend 0 if uneven amount of hex digits
    $serial_f = join ":", unpack("(A2)*", $serial);
    note "Certificate serial: $serial_f";
} "Fetch certificate (HASH)";

# Fetch certificate - PEM Format
my ($tmp, $tmp_name) = tempfile(UNLINK => 1);
my $pem;
$ENV{OPENSSL_CONF} = "/dev/null"; # prevents "WARNING: can't open config file: ..."
lives_and {
    $pem = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'PEM' });
    print $tmp $pem;
    close $tmp;
    my $cmp_serial = `openssl x509 -in $tmp_name -inform PEM -serial`;
    like $cmp_serial, qr/$serial/i;
} "Fetch certificate (PEM)";

# Fetch certificate - DER Format
lives_and {
    my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'DER' });
    open my $fh, ">", "$tempdir/cert.der";
    print $fh $result;
    close $fh;
    $ENV{OPENSSL_CONF} = "/dev/null"; # prevents "WARNING: can't open config file: ..."
    my $cmp_serial = `openssl x509 -in "$tempdir/cert.der" -inform DER -serial`;
    like $cmp_serial, qr/$serial/i;
} "Fetch certificate (DER)";

## Compare PEM and DER
my $pem2 = `openssl x509 -in "$tempdir/cert.der" -inform DER`;
(my $pem_short = $pem) =~ s{\s}{}gxms; $pem2 =~ s{\s}{}gxms; # Clear all whitespace to compare
is $pem_short, $pem2, 'DER matches PEM';

# Fetch certificate - TXT Format
lives_and {
    my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'TXT' });
    like $result, qr/$serial_f/i;
} "Fetch certificate (TXT)";

# Fetch certificate - DBINFO Format
my $dbinfo_serial;
lives_and {
    my $result = $oxitest->api2_command("get_cert" => { identifier => $cert_id, format => 'DBINFO', attribute => '%' });
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
    }), "DBINFO contains relevant elements" or diag explain $result;
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

#
# get_cert_identifier
#
# note: we cannot compare to $cert_id as this originates from the function we want to test

# query fingerprint (SHA1 hash of DER) via OpenSSL
$ENV{OPENSSL_CONF} = "/dev/null"; # prevents "WARNING: can't open config file: ..."
my $fp = `openssl x509 -in "$tempdir/cert.der" -inform der -fingerprint -sha1 -noout`;
($fp) = $fp =~ / ^ [^=]+ = (.*) /x;             # cut off "SHA1 Fingerprint="
$fp =~ s/://g;                                  # AA:E8:FD:27:1A... --> AAE8FD271A...
my $fp_base64 = encode_base64(pack('H*', $fp)); # convert to bytes and then to base64
$fp_base64 =~ tr/+\//-_/;                       # RFC 3548 URL and filename safe base64

lives_and {
    my $result = $oxitest->api2_command("get_cert_identifier" => { cert => $pem });
    # $fp_base64 is padded with "=" at the end but $result is not
    like $fp_base64, qr/\Q$result\E/;
} "get_cert_identifier - retrieve certificate ID";


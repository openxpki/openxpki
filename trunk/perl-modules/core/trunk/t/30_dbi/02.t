use strict;
use warnings;
use Test::More;
plan tests => 13;

diag "OpenXPKI::Server::DBI: CA setup and empty CRL\n";

use OpenXPKI::Server::DBI;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Crypto::CRL;

use Data::Dumper;

ok(1);

our $dbi;
our $token;
require 't/30_dbi/common.pl';

ok(1);

my $cert = OpenXPKI->read_file ("t/25_crypto/ca1/cacert.pem");
my $cert2 = OpenXPKI->read_file ("t/25_crypto/ca2/cacert.pem");
$cert = OpenXPKI::Crypto::X509->new (DATA => $cert, TOKEN => $token);
$cert2 = OpenXPKI::Crypto::X509->new (DATA => $cert2, TOKEN => $token);
my $crl = OpenXPKI->read_file ("t/25_crypto/ca1/crl.pem");
$crl = OpenXPKI::Crypto::CRL->new (DATA => $crl, TOKEN => $token);
$cert->set_header_attribute (PKI_REALM => "Test Root CA",
                             CA        => "INTERNAL_CA_1");
$crl->set_header_attribute (PKI_REALM => "Test Root CA",
                            CA        => "INTERNAL_CA_1");

ok($cert and $crl);

# insert CA certificate
$cert->set_status ("ISSUED");
ok($cert);

# write self-signed root cert to DB

my %hash = $cert->to_db_hash();
$hash{'ISSUER_IDENTIFIER'} = 'dummy';
$hash{PKI_REALM} = '';
my $serial = $dbi->get_new_serial(
    TABLE => 'CERTIFICATE',
);
$hash{'CERTIFICATE_SERIAL'} = $serial;

$dbi->insert (TABLE => "CERTIFICATE", HASH => \%hash);

my $attribute_serial = 1;
$dbi->insert(
    TABLE => 'CERTIFICATE_ATTRIBUTES',
    HASH => 
    {
	IDENTIFIER               => $cert->get_identifier(),
	ATTRIBUTE_KEY            => 'dummy key',
	ATTRIBUTE_VALUE          => 'dummy value',
	ATTRIBUTE_SERIAL         => $attribute_serial++,
    });

$dbi->commit();
ok(1);
if ($ENV{DEBUG}) {
    diag "Certificate with identifier " . $cert->get_identifier()
        . " inserted.\n";
}

%hash = $cert2->to_db_hash();
$hash{'ISSUER_IDENTIFIER'} = 'dummy';
$hash{PKI_REALM} = '';
$serial = $dbi->get_new_serial(
    TABLE => 'CERTIFICATE',
);
$hash{'CERTIFICATE_SERIAL'} = $serial;

$dbi->insert (TABLE => "CERTIFICATE", HASH => \%hash);
$dbi->insert(
    TABLE => 'CERTIFICATE_ATTRIBUTES',
    HASH => 
    {
	IDENTIFIER               => $cert2->get_identifier(),
	ATTRIBUTE_KEY            => 'dummy key',
	ATTRIBUTE_VALUE          => 'dummy value',
	ATTRIBUTE_SERIAL         => $attribute_serial++,
    });
$dbi->commit();
ok(1);
if ($ENV{DEBUG}) {
    diag "Certificate with identifier " . $cert2->get_identifier()
        . " inserted.\n";
}

# insert aliases

$dbi->insert(
    TABLE => 'ALIASES',
    HASH  => {
        IDENTIFIER => $cert->get_identifier(),
        PKI_REALM  => 'Test Root CA',
        ALIAS      => 'INTERNAL_CA_1',
    },
);
$dbi->commit();
ok(1);

$dbi->insert(
    TABLE => 'ALIASES',
    HASH  => {
        IDENTIFIER => $cert2->get_identifier(),
        PKI_REALM  => 'Test Root CA',
        ALIAS      => 'INTERNAL_CA_2',
    },
);
$dbi->commit();
ok(1);
# insert first CRL

my %db_hash = $crl->to_db_hash();
$db_hash{PKI_REALM} = 'Test Root CA';
$db_hash{ISSUER_IDENTIFIER} = $cert->get_identifier();
$serial = $dbi->get_new_serial(
        TABLE => 'CRL',
);
$db_hash{'CRL_SERIAL'} = $serial;
$dbi->insert (TABLE => "CRL", HASH => \%db_hash);
$dbi->commit();

ok(1);

1;

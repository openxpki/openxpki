use strict;
use warnings;
use Test;
BEGIN { plan tests => 13 };

print STDERR "OpenXPKI::Server::DBI: CA setup and empty CRL\n";

use OpenXPKI::Server::DBI;

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
$cert->set_status ("VALID");
ok($cert);

# write self-signed root cert to DB

my %hash = $cert->to_db_hash();
$hash{PKI_REALM} = '';

$dbi->insert (TABLE => "CERTIFICATE", HASH => \%hash);
$dbi->commit();
ok(1);
if ($ENV{DEBUG}) {
    print STDERR "Certificate with identifier " . $cert->get_identifier()
        . " inserted.\n";
}

%hash = $cert2->to_db_hash();
$hash{PKI_REALM} = '';

$dbi->insert (TABLE => "CERTIFICATE", HASH => \%hash);
$dbi->commit();
ok(1);
if ($ENV{DEBUG}) {
    print STDERR "Certificate with identifier " . $cert2->get_identifier()
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

# TODO: write CRL->to_db_hash() and use here
#$dbi->insert (TABLE => "CRL", OBJECT => $crl);
#$dbi->commit();
#
#ok(1);

1;

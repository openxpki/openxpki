use strict;
use warnings;
use Test;
BEGIN { plan tests => 12 };

print STDERR "OpenXPKI::Server::DBI: CA setup and empty CRL\n";

use OpenXPKI::Server::DBI;

ok(1);

our $dbi;
our $token;
require 't/30_dbi/common.pl';

ok(1);

my $cert = OpenXPKI->read_file ("t/25_crypto/cacert.pem");
$cert = OpenXPKI::Crypto::X509->new (DATA => $cert, TOKEN => $token);
my $crl = OpenXPKI->read_file ("t/25_crypto/crl.pem");
$crl = OpenXPKI::Crypto::CRL->new (DATA => $crl, TOKEN => $token);
$cert->set_header_attribute (PKI_REALM => "Test Root CA",
                             CA        => "INTERNAL_CA_1");
$crl->set_header_attribute (PKI_REALM => "Test Root CA",
                            CA        => "INTERNAL_CA_1");

ok($cert and $crl);

# insert CA certificate
$cert->set_status ("VALID");
ok($cert);
$dbi->insert (TABLE => "CERTIFICATE", OBJECT => $cert);
ok(1);

# create new PKI realm with selfsigned root certificate

my %hash = (
            PKI_REALM          => "Test Root CA",
            CA                 => "INTERNAL_CA_1",
            CERTIFICATE_SERIAL => $cert->get_serial(),
            ISSUING_REALM      => "Test Root CA",
            ISSUING_CA         => "INTERNAL_CA_1"
           );
$dbi->insert (TABLE => "CA", HASH => \%hash);
ok(1);

# insert first CRL

$dbi->insert (TABLE => "CRL", OBJECT => $crl);
ok(1);

1;

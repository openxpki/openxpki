use strict;
use warnings;
use Test;
BEGIN { plan tests => 15 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::CRL\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (TYPE => "CA", NAME => "INTERNAL_CA_1", PKI_REALM => "Test Root CA");
ok (1);

## create CRL
my $crl = OpenXPKI->read_file ("t/25_crypto/crl.pem");
ok(1);

## get object
$crl = $token->get_object (DATA => $crl, TYPE => "CRL");
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "issuer", "issuer_hash", "serial",
                  "last_update", "next_update", "fingerprint", #"extensions",
                  "revoked", "signature_algorithm", "signature")
{
    my $result = $crl->$func();
    if (defined $result)
    {
        ok(1);
        print STDERR "$func: $result\n" if ($ENV{DEBUG});
    } else {
        ok(0);
        print STDERR "Error: function $func failed\n";
    }
}

1;

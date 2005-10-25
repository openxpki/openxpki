use strict;
use warnings;
use Test;
BEGIN { plan tests => 15 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::CRL\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
eval `cat t/crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (1);

## create CRL
my $crl = OpenXPKI->read_file ("t/crypto/crl.pem");
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

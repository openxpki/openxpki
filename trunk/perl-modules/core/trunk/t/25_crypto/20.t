use strict;
use warnings;
use Test;
BEGIN { plan tests => 19 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::PKCS10\n";

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

## create PKCS#10 request
my $csr = OpenXPKI->read_file ("t/25_crypto/pkcs10.pem");
ok(1);

## get object
$csr = $token->get_object (DATA => $csr, TYPE => "CSR");
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "subject", "subject_hash", "fingerprint",
                  "emailaddress", "extensions", # "attributes",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash",
                  "signature_algorithm", "signature")
{
    my $result = $csr->$func();
    if (defined $result or $func eq "extensions")
    {
        ok(1);
        print STDERR "$func: $result\n" if ($ENV{DEBUG});
    } else {
        ok(0);
        print STDERR "Error: function $func failed\n";
    }
}

1;

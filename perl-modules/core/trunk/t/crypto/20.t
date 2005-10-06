use strict;
use warnings;
use Test;
BEGIN { plan tests => 17 };

print STDERR "OpenXPKI::Crypto::OpenSSL::PKCS10\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
ok(1);

## init the XML cache

my $cache = OpenXPKI::XML::Cache->new(DEBUG  => 0,
                                      CONFIG => [ "t/crypto/token.xml" ]);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (1);

## create PKCS#10 request
my $csr = OpenXPKI->read_file ("t/crypto/pkcs10.pem");
ok(1);

## get object
$csr = $token->get_object (DATA => $csr, TYPE => "CSR");
ok(1);

## check that all required functions are available and work
foreach my $func ("version", "subject", "subject_hash", "fingerprint",
                  "emailaddress", # "extensions", "attributes",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "signature_algorithm", "signature")
{
    my $result = $csr->$func();
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

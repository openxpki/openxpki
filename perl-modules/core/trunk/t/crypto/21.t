use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::OpenSSL::SPKAC\n";

use OpenXPKI::XML::Cache;
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

## create SPKAC request
$ENV{pwd} = OpenXPKI->read_file ("t/crypto/passwd.txt");
ok(1);
my $spkac = `openssl spkac -key t/crypto/rsa.pem -passin env:pwd`;
if ($spkac)
{
    ok(1);
} else {
    ok(0);
}

## get object
$spkac = $token->get_object (DATA => $spkac, TYPE => "CSR", FORMAT => "SPKAC");
ok(1);

## check that all required functions are available and work
foreach my $func ("pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent")
{
    my $result = $spkac->$func();
    if ($result)
    {
        ok(1);
        print STDERR "$func: $result\n" if ($ENV{DEBUG});
    } else {
        ok(0);
        print STDERR "Error: function $func failed\n";
    }
}

1;

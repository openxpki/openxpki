use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::SPKAC\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (TYPE => "CA", NAME => "INTERNAL_CA_1", PKI_REALM => "Test Root CA");
ok (1);

## create SPKAC request
$ENV{pwd} = OpenXPKI->read_file ("$basedir/ca1/passwd.txt");
ok(1);
my $spkac = `openssl spkac -key $basedir/ca1/rsa.pem -passin env:pwd`;
if ($spkac)
{
    ok(1);
} else {
    ok(0);
}

## get object
$spkac = $token->get_object ({DATA => $spkac, TYPE => "CSR", FORMAT => "SPKAC"});
ok(1);

## check that all required functions are available and work
foreach my $func ("pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent")
{
    ## FIXME: this is a bypass of the API !!!
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

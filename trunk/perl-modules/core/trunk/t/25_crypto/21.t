use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Backend::OpenSSL::SPKAC\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
our $cacert;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new ();
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "CA", 
    ID => "INTERNAL_CA_1", 
    PKI_REALM => "Test Root CA",
    CERTIFICATE => $cacert,
);
ok (1);

## create SPKAC request
$ENV{pwd} = OpenXPKI->read_file ("$basedir/ca1/passwd.txt");
ok(1);

my $shell_path = `cat t/cfg.binary.openssl`; # openssl executable to use
my $spkac = `$shell_path spkac -key $basedir/ca1/rsa.pem -passin env:pwd`;
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

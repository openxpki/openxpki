use strict;
use warnings;
use Test;
BEGIN { plan tests => 25 };

print STDERR "OpenXPKI::Crypto::OpenSSL::X509\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
ok(1);

## init the XML cache

my $cache = OpenXPKI::XML::Cache->new(DEBUG  => 0,
                                      CONFIG => [ "t/crypto/token.xml" ]);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0);
ok (not defined $mgmt);
$mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
ok (defined $mgmt);
if (not defined $mgmt)
{
    print STDERR "errno: ".OpenXPKI::Crypto::TokenManager::errno."\n";
    print STDERR "errval: ".OpenXPKI::Crypto::TokenManager::errval."\n";
}

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (defined $token);
if (not defined $token)
{
    print STDERR "errno: ".$mgmt->errno()."\n";
    print STDERR "errval: ".$mgmt->errval()."\n";
}

## create cert
my $cert = OpenXPKI->read_file ("t/crypto/cert.pem");
if ($cert)
{
    ok(1);
} else {
    ok(0);
}

## get object
$cert = $token->get_object (DATA => $cert, TYPE => "X509");
if ($cert)
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## check that all required functions are available and work
foreach my $func ("version", "serial", "subject", "openssl_subject", "issuer",
                  "notbefore", "notafter", "fingerprint", #"alias",
                  "subject_hash", "emailaddress", "extensions",
                  "pubkey_algorithm", "pubkey", "keysize", "modulus", "exponent",
                  "pubkey_hash", "signature_algorithm", "signature")
{
    my $result = $cert->$func();
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

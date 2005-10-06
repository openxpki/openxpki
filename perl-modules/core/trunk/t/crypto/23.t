use strict;
use warnings;
use Test;
BEGIN { plan tests => 16 };

print STDERR "OpenXPKI::Crypto::OpenSSL::CRL\n";

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

## create CRL
my $crl = OpenXPKI->read_file ("t/crypto/crl.pem");
if ($crl)
{
    ok(1);
} else {
    ok(0);
}

## get object
$crl = $token->get_object (DATA => $crl, TYPE => "CRL");
if ($crl)
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

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

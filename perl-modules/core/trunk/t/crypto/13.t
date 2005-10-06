use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Command: PKCS#7 tests\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI qw (read_file);
ok(1);

## init the XML cache

my $cache = OpenXPKI::XML::Cache->new(DEBUG  => 0,
                                      CONFIG => [ "t/crypto/token.xml" ]);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
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

## load data

my $passwd = OpenXPKI->read_file ("t/crypto/passwd.txt");
my $rsa    = OpenXPKI->read_file ("t/crypto/rsa.pem");
my $cert   = OpenXPKI->read_file ("t/crypto/cert.pem");
ok($passwd and $rsa and $cert);

my $content = "This is for example a passprase.";

## sign content

my $sig = $token->command ("pkcs7_sign",
                           CONTENT   => $content,
                           CERT      => $cert,
                           KEY       => $rsa,
                           PASSWD    => $passwd);
if ($sig)
{
    ok(1);
    print STDERR "PKCS#7 signature: $sig\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## encrypt content

$content = $token->command ("pkcs7_encrypt",
                            CONTENT   => $content,
                            CERT      => $cert);
if ($content)
{
    ok(1);
    print STDERR "PKCS#7 encryption: $content\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## decrypt content

$content = $token->command ("pkcs7_decrypt",
                            PKCS7  => $content,
                            CERT   => $cert,
                            KEY    => $rsa,
                            PASSWD => $passwd);
if ($content)
{
    ok(1);
    print STDERR "PKCS#7 content: $content\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}
ok ($content eq "This is for example a passprase.");

## verify signature

my $result = $token->command ("pkcs7_verify",
                              CONTENT => $content,
                              PKCS7   => $sig,
                              CHAIN   => "t/crypto/cacert.pem");
if ($result)
{
    ok(1);
    print STDERR "PKCS#7 external chain verify: $result\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}
$result = $token->command ("pkcs7_verify",
                           CONTENT => $content,
                           PKCS7   => $sig);
if ($result)
{
    ok(1);
    print STDERR "PKCS#7 token chain verify: $result\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## extract available chain from signature

$result = $token->command ("pkcs7_get_chain",
                           SIGNER => $result,
                           PKCS7  => $sig);
if ($result)
{
    ok(1);
    print STDERR "PKCS#7 get_chain: $result\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

1;

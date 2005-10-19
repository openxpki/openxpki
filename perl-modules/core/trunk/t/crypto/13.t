use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Command: PKCS#7 tests\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI qw (read_file);

our $cache;
eval `cat t/crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
ok(1);

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok(1);

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
ok(1);
print STDERR "PKCS#7 signature: $sig\n" if ($ENV{DEBUG});

## encrypt content

$content = $token->command ("pkcs7_encrypt",
                            CONTENT   => $content,
                            CERT      => $cert);
ok(1);

## decrypt content

$content = $token->command ("pkcs7_decrypt",
                            PKCS7  => $content,
                            CERT   => $cert,
                            KEY    => $rsa,
                            PASSWD => $passwd);
ok(1);
print STDERR "PKCS#7 content: $content\n" if ($ENV{DEBUG});
ok ($content eq "This is for example a passprase.");

## verify signature

my $result = $token->command ("pkcs7_verify",
                              CONTENT => $content,
                              PKCS7   => $sig,
                              CHAIN   => "t/crypto/cacert.pem");
ok(1);
print STDERR "PKCS#7 external chain verify: $result\n" if ($ENV{DEBUG});
$result = $token->command ("pkcs7_verify",
                           CONTENT => $content,
                           PKCS7   => $sig);
ok(1);
print STDERR "PKCS#7 token chain verify: $result\n" if ($ENV{DEBUG});

## extract available chain from signature

$result = $token->command ("pkcs7_get_chain",
                           SIGNER => $result,
                           PKCS7  => $sig);
ok(1);
print STDERR "PKCS#7 get_chain: $result\n" if ($ENV{DEBUG});

1;

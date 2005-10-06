
use strict;
use warnings;
use Test;
BEGIN { plan tests => 8 };

print STDERR "OpenXPKI::Crypto::Command: Create a CA\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
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

## create CA RSA key (use passwd from token.xml)
my $key = $token->command ("create_rsa", KEY_LENGTH => "1024", ENC_ALG => "aes256");
if ($key)
{
    ok (1);
    print STDERR "CA RSA: $key\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}

## create CA CSR
my $csr = $token->command ("create_pkcs10",
                           SUBJECT => "cn=CA_1,dc=OpenXPKI,dc=info");
if ($csr)
{
    ok (1);
    print STDERR "CA CSR: $csr\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}

## create CA cert
my $cert = $token->command ("create_cert", CSR => $csr);
if ($cert)
{
    ok (1);
    print STDERR "CA cert: $cert\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}

## check that the CA is ready for further tests
if (not -e "t/crypto/cakey.pem")
{
    ok(0);
    print STDERR "Missing CA key\n";
} else {
    ok(1);
}
if (not -e "t/crypto/cacert.pem")
{
    ok(0);
    print STDERR "Missing CA cert\n";
} else {
    ok(1);
}

1;

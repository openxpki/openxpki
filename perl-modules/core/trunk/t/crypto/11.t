use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Command: Create a user cert and issue a CRL\n";

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

## create PIN (128 bit == 16 byte)
my $passwd = $token->command ("create_random", RANDOM_LENGTH => 16);
if ($passwd)
{
    ok (1);
    print STDERR "passwd: $passwd\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}
OpenXPKI->write_file (FILENAME => "t/crypto/passwd.txt", CONTENT => $passwd);

## create DSA key
my $key = $token->command ("create_dsa", KEY_LENGTH => "1024", ENC_ALG => "aes256", PASSWD => $passwd);
if ($key)
{
    ok (1);
    print STDERR "DSA: $key\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}
OpenXPKI->write_file (FILENAME => "t/crypto/dsa.pem", CONTENT => $key);

## create RSA key
$key = $token->command ("create_rsa", KEY_LENGTH => "1024", ENC_ALG => "aes256", PASSWD => $passwd);
if ($key)
{
    ok (1);
    print STDERR "RSA: $key\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}
OpenXPKI->write_file (FILENAME => "t/crypto/rsa.pem", CONTENT => $key);

## create CSR
my $csr = $token->command ("create_pkcs10",
                           CONFIG  => "t/crypto/openssl.cnf",
                           KEY     => $key,
                           PASSWD  => $passwd,
                           SUBJECT => "cn=John Doe,dc=OpenCA,dc=info");
if ($csr)
{
    ok (1);
    print STDERR "CSR: $csr\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}
OpenXPKI->write_file (FILENAME => "t/crypto/pkcs10.pem", CONTENT => $csr);

## create cert
my $cert = $token->command ("issue_cert",
                            CSR    => $csr,
                            CONFIG => "t/crypto/openssl.cnf",
                            SERIAL => 1);
if ($cert)
{
    ok (1);
    print STDERR "cert: $cert\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}
OpenXPKI->write_file (FILENAME => "t/crypto/cert.pem", CONTENT => $cert);

## build the PKCS#12 file
my $pkcs12 = $token->command ("create_pkcs12",
                              PASSWD  => $passwd,
                              KEY     => $key,
                              CERT    => $cert,
                              CHAIN   => $token->get_certfile());
if ($pkcs12)
{
    ok (1);
    print STDERR "PKCS#12 length: ".length ($pkcs12)."\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}

## create CRL
my $crl = $token->command ("issue_crl", REVOKED => [$cert], SERIAL => 1);
if ($crl)
{
    ok (1);
    print STDERR "CRL: $crl\n" if ($ENV{DEBUG});
} else {
    ok (0);
    print STDERR "Error: ".$token->errval()."\n";
}
OpenXPKI->write_file (FILENAME => "t/crypto/crl.pem", CONTENT => $crl);

1;

use strict;
use warnings;
use Test;
BEGIN { plan tests => 15 };

print STDERR "OpenXPKI::Crypto::Command: Conversion tests\n";

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
my $dsa    = OpenXPKI->read_file ("t/crypto/dsa.pem");
my $rsa    = OpenXPKI->read_file ("t/crypto/rsa.pem");
my $csr    = OpenXPKI->read_file ("t/crypto/pkcs10.pem");
my $cert   = OpenXPKI->read_file ("t/crypto/cert.pem");
my $crl    = OpenXPKI->read_file ("t/crypto/crl.pem");
ok($passwd and $dsa and $rsa and $csr and $cert and $crl);

## DSA KEY: PEM --> DER
if ($token->command ("convert_key",
                     DATA   => $dsa,
                     IN     => "DSA",
                     OUT    => "DER",
                     PASSWD => $passwd))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## RSA KEY: PEM --> DER
if ($token->command ("convert_key",
                     DATA   => $rsa,
                     IN     => "RSA",
                     OUT    => "DER",
                     PASSWD => $passwd))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## DSA KEY: PEM --> PKCS#8
if ($token->command ("convert_key",
                     DATA   => $dsa,
                     IN     => "DSA",
                     OUT    => "PKCS8",
                     PASSWD => $passwd))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## RSA KEY: PEM --> PKCS#8
my $pkcs8 = $token->command ("convert_key",
                             DATA   => $rsa,
                             IN     => "RSA",
                             OUT    => "PKCS8",
                             PASSWD => $passwd);
if ($pkcs8)
{
    ok(1);
    print STDERR "PKCS#8 RSA key: $pkcs8\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## PKCS#8: PEM --> DER
if ($token->command ("convert_key",
                     DATA   => $pkcs8,
                     IN     => "PKCS8",
                     OUT    => "DER",
                     PASSWD => $passwd))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## PKCS10: PEM --> DER
if ($token->command ("convert_pkcs10", DATA => $csr, OUT => "DER"))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## PKCS10: PEM --> TXT
if ($token->command ("convert_pkcs10", DATA => $csr, OUT => "TXT"))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## Cert: PEM --> DER
if ($token->command ("convert_cert", DATA => $cert, OUT => "DER"))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## Cert: PEM --> TXT
if ($token->command ("convert_cert", DATA => $cert, OUT => "TXT"))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## CRL: PEM --> DER
if ($token->command ("convert_crl", DATA => $crl, OUT => "DER"))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

## CRL: PEM --> TXT
if ($token->command ("convert_crl", DATA => $crl, OUT => "TXT"))
{
    ok(1);
} else {
    ok(0);
    print STDERR "Error: ".$token->errval()."\n";
}

1;

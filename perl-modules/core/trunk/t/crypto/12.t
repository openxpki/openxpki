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
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (1);

## load data
my $passwd = OpenXPKI->read_file ("t/crypto/passwd.txt");
my $dsa    = OpenXPKI->read_file ("t/crypto/dsa.pem");
my $rsa    = OpenXPKI->read_file ("t/crypto/rsa.pem");
my $csr    = OpenXPKI->read_file ("t/crypto/pkcs10.pem");
my $cert   = OpenXPKI->read_file ("t/crypto/cert.pem");
my $crl    = OpenXPKI->read_file ("t/crypto/crl.pem");
ok($passwd and $dsa and $rsa and $csr and $cert and $crl);

## DSA KEY: PEM --> DER
$token->command ("convert_key",
                 DATA   => $dsa,
                 IN     => "DSA",
                 OUT    => "DER",
                 PASSWD => $passwd);
ok(1);

## RSA KEY: PEM --> DER
$token->command ("convert_key",
                 DATA   => $rsa,
                 IN     => "RSA",
                 OUT    => "DER",
                 PASSWD => $passwd);
ok(1);

## DSA KEY: PEM --> PKCS#8
$token->command ("convert_key",
                 DATA   => $dsa,
                 IN     => "DSA",
                 OUT    => "PKCS8",
                 PASSWD => $passwd);
ok(1);

## RSA KEY: PEM --> PKCS#8
my $pkcs8 = $token->command ("convert_key",
                             DATA   => $rsa,
                             IN     => "RSA",
                             OUT    => "PKCS8",
                             PASSWD => $passwd);
ok(1);

## PKCS#8: PEM --> DER
$token->command ("convert_key",
                 DATA   => $pkcs8,
                 IN     => "PKCS8",
                 OUT    => "DER",
                 PASSWD => $passwd);
ok(1);

## PKCS10: PEM --> DER
$token->command ("convert_pkcs10", DATA => $csr, OUT => "DER");
ok(1);

## PKCS10: PEM --> TXT
$token->command ("convert_pkcs10", DATA => $csr, OUT => "TXT");
ok(1);

## Cert: PEM --> DER
$token->command ("convert_cert", DATA => $cert, OUT => "DER");
ok(1);

## Cert: PEM --> TXT
$token->command ("convert_cert", DATA => $cert, OUT => "TXT");
ok(1);

## CRL: PEM --> DER
$token->command ("convert_crl", DATA => $crl, OUT => "DER");
ok(1);

## CRL: PEM --> TXT
$token->command ("convert_crl", DATA => $crl, OUT => "TXT");
ok(1);

1;

use strict;
use warnings;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Crypto::Command: Create a user cert and issue a CRL\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (TYPE => "CA", NAME => "INTERNAL_CA_1", PKI_REALM => "Test Root CA");
ok (1);

## create PIN (128 bit == 16 byte)
my $passwd = $token->command ("create_random", RANDOM_LENGTH => 16);
ok (1);
print STDERR "passwd: $passwd\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/passwd.txt", CONTENT => $passwd);

## create DSA key
my $key = $token->command ("create_key",
                           TYPE       => "DSA",
                           KEY_LENGTH => "1024",
                           ENC_ALG    => "aes256",
                           PASSWD     => $passwd);
ok (1);
print STDERR "DSA: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/dsa.pem", CONTENT => $key);

## create EC key
$key = $token->command ("create_key",
                        TYPE       => "EC",
                        CURVE_NAME => "sect571r1",
                        ENC_ALG    => "aes256",
                        PASSWD     => $passwd);
ok (1);
print STDERR "EC: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/ec.pem", CONTENT => $key);

## create RSA key
$key = $token->command ("create_key",
                        TYPE       => "RSA",
                        KEY_LENGTH => "1024",
                        ENC_ALG    => "aes256",
                        PASSWD     => $passwd);
ok (1);
print STDERR "RSA: $key\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/rsa.pem", CONTENT => $key);

## create CSR
my $csr = $token->command ("create_pkcs10",
                           CONFIG  => "$basedir/ca1/openssl.cnf",
                           KEY     => $key,
                           PASSWD  => $passwd,
                           SUBJECT => "cn=John Doe,dc=OpenCA,dc=info");
ok (1);
print STDERR "CSR: $csr\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/pkcs10.pem", CONTENT => $csr);

## create cert
my $cert = $token->command ("issue_cert",
                            CSR    => $csr,
                            CONFIG => "$basedir/ca1/openssl.cnf",
                            SERIAL => 1);
ok (1);
print STDERR "cert: $cert\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/cert.pem", CONTENT => $cert);

## build the PKCS#12 file
my $pkcs12 = $token->command ("create_pkcs12",
                              PASSWD  => $passwd,
                              KEY     => $key,
                              CERT    => $cert,
                              CHAIN   => $token->get_certfile());
ok (1);
print STDERR "PKCS#12 length: ".length ($pkcs12)."\n" if ($ENV{DEBUG});

## create CRL
my $crl = $token->command ("issue_crl", REVOKED => [$cert], SERIAL => 1);
ok (1);
print STDERR "CRL: $crl\n" if ($ENV{DEBUG});
OpenXPKI->write_file (FILENAME => "$basedir/ca1/crl.pem", CONTENT => $crl);

1;

use strict;
use warnings;
use Test::More;
use English;

plan tests => 16;


diag "OpenXPKI::Crypto::Command: Conversion tests\n" if $ENV{VERBOSE};

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI qw (read_file);

our $cache;
our $basedir;
our $cacert;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 15 if $EVAL_ERROR;

my $mgmt = OpenXPKI::Crypto::TokenManager->new({'IGNORE_CHECK' => 1});
ok ($mgmt, 'Create OpenXPKI::Crypto::TokenManager instance');

TODO: {
    todo_skip 'See Issue #188', 14;

my $token = $mgmt->get_token ({
   TYPE => 'certsign',
   NAME => 'test-ca',
   CERTIFICATE => {
        DATA => $cacert,
        IDENTIFIER => 'ignored',
   }
});

ok (1);

## load data
my $passwd = OpenXPKI->read_file ("$basedir/test-ca/passwd.txt");
my $dsa    = OpenXPKI->read_file ("$basedir/test-ca/dsa.pem");
my $rsa    = OpenXPKI->read_file ("$basedir/test-ca/rsa.pem");
my $csr    = OpenXPKI->read_file ("$basedir/test-ca/pkcs10.pem");
my $cert   = OpenXPKI->read_file ("$basedir/test-ca/cert.pem");
my $crl    = OpenXPKI->read_file ("$basedir/test-ca/crl.pem");
ok($passwd and $dsa and $rsa and $csr and $cert and $crl);

## DSA KEY: PEM --> DER
$token->command ({COMMAND => "convert_key",
                  DATA    => $dsa,
                  IN      => "DSA",
                  OUT     => "DER",
                  PASSWD  => $passwd});
ok(1);

## RSA KEY: PEM --> DER
$token->command ({COMMAND => "convert_key",
                  DATA    => $rsa,
                  IN      => "RSA",
                  OUT     => "DER",
                  PASSWD  => $passwd});
ok(1);

## DSA KEY: PEM --> PKCS#8
$token->command ({COMMAND => "convert_key",
                  DATA    => $dsa,
                  IN      => "DSA",
                  OUT     => "PKCS8",
                  PASSWD  => $passwd});
ok(1);

## RSA KEY: PEM --> PKCS#8
my $pkcs8 = $token->command ({COMMAND => "convert_key",
                              DATA   => $rsa,
                              IN     => "RSA",
                              OUT    => "PKCS8",
                              PASSWD => $passwd});
ok(1);

## PKCS#8: PEM --> DER
$token->command ({COMMAND => "convert_key",
                  DATA    => $pkcs8,
                  IN      => "PKCS8",
                  OUT     => "DER",
                  PASSWD  => $passwd});
ok(1);

## PKCS10: PEM --> DER
my $der_csr = $token->command ({COMMAND => "convert_pkcs10",
                  DATA    => $csr,
                  OUT => "DER"});
ok(1);

## PKCS10: PEM --> TXT
$token->command ({COMMAND => "convert_pkcs10",
                  DATA    => $csr,
                  OUT     => "TXT"});
ok(1);

## PKCS10: DER -> PEM
my $pem_csr = $token->command({
    COMMAND => 'convert_pkcs10',
    DATA    => $der_csr,
    IN      => 'DER',
    OUT     => 'PEM',
});
is($pem_csr, $csr, 'Converting from DER to PEM recovers original PEM format CSR');
## Cert: PEM --> DER
$token->command ({COMMAND => "convert_cert",
                  DATA    => $cert,
                  OUT     => "DER"});
ok(1);

## Cert: PEM --> TXT
$token->command ({COMMAND => "convert_cert",
                  DATA    => $cert,
                  OUT     => "TXT"});
ok(1);

## CRL: PEM --> DER
$token->command ({COMMAND => "convert_crl",
                  DATA    => $crl,
                  OUT     => "DER"});
ok(1);

## CRL: PEM --> TXT
$token->command ({COMMAND => "convert_crl",
                  DATA    => $crl,
                  OUT     => "TXT"});
ok(1);

}
}
1;

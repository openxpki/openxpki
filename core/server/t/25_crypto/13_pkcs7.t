use strict;
use warnings;
use Test::More;
use English;

plan tests => 10;

print STDERR "OpenXPKI::Crypto::Command: PKCS#7 tests\n" if $ENV{VERBOSE};

use OpenXPKI::Debug;
##$OpenXPKI::Debug::LEVEL{'.*'} = 100;
require OpenXPKI::Crypto::TokenManager;
use OpenXPKI qw (read_file);

our $cache;
our $basedir;
our $cacert;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 9 if $EVAL_ERROR;


my $mgmt = OpenXPKI::Crypto::TokenManager->new({'IGNORE_CHECK' => 1});
ok ($mgmt, 'Create OpenXPKI::Crypto::TokenManager instance');

TODO: {
    todo_skip 'See Issue #188', 8;
my $token = $mgmt->get_token ({
   TYPE => 'certsign',
   NAME => 'test-ca',
   CERTIFICATE => {
        DATA => $cacert,
        IDENTIFIER => 'ignored',
   }
});

ok(1);

## load data

my $passwd = OpenXPKI->read_file ("$basedir/test-ca/passwd.txt");
my $rsa    = OpenXPKI->read_file ("$basedir/test-ca/rsa.pem");
my $cert   = OpenXPKI->read_file ("$basedir/test-ca/cert.pem");
ok($passwd and $rsa and $cert);

my $content = "This is for example a passprase.";

## sign content

my $sig = $token->command ({COMMAND   => "pkcs7_sign",
                            CONTENT   => $content,
                            CERT      => $cert,
                            KEY       => $rsa,
                            PASSWD    => $passwd});
ok(1);
print STDERR "PKCS#7 signature: $sig\n" if ($ENV{DEBUG});

## encrypt content

$content = $token->command ({COMMAND   => "pkcs7_encrypt",
                             CONTENT   => $content,
                             CERT      => $cert});
ok(1);

## decrypt content

$content = $token->command ({COMMAND => "pkcs7_decrypt",
                             PKCS7   => $content,
                             CERT    => $cert,
                             KEY     => $rsa,
                             PASSWD  => $passwd});
ok(1);
print STDERR "PKCS#7 content: $content\n" if ($ENV{DEBUG});
ok ($content eq "This is for example a passprase.");

## verify signature

my @chain = [ $cacert ];

my $result = $token->command ({COMMAND => "pkcs7_verify",
                               CONTENT => $content,
                               PKCS7   => $sig,
                               CHAIN   => @chain});
ok(1);
print STDERR "PKCS#7 external chain verify: $result\n" if ($ENV{DEBUG});

## extract available chain from signature

$result = $token->command ({COMMAND => "pkcs7_get_chain",
                            SIGNER  => $result,
                            PKCS7   => $sig});
ok(1);
print STDERR "PKCS#7 get_chain: $result\n" if ($ENV{DEBUG});
}

}
1;

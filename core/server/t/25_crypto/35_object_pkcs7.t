use strict;
use warnings;
use Test::More;
use English;

plan tests => 12;

TODO: {
    todo_skip 'See Issue #188', 12;

print STDERR "OpenXPKI::Crypto::PKCS7\n" if $ENV{VERBOSE};

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI qw (read_file);
# TODO: See Issue #188 - PKCS7 has been removed?
#use OpenXPKI::Crypto::PKCS7;
use Time::HiRes;

our $cache;
our $cacert;
our $basedir;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 11 if $EVAL_ERROR;


my $mgmt = OpenXPKI::Crypto::TokenManager->new;
ok ($mgmt, 'Create OpenXPKI::Crypto::TokenManager instance');

my $token = $mgmt->get_token ({
   TYPE => 'certsign',
   NAME => 'test-ca',
   CERTIFICATE => {
        DATA => $cacert,
        IDENTIFIER => 'ignored',
   }
});

ok (defined $token, 'Parameter checks for get_token');


## load data

my $passwd = OpenXPKI->read_file ("$basedir/test-ca/passwd.txt");
my $rsa    = OpenXPKI->read_file ("$basedir/test-ca/rsa.pem");
my $cert   = OpenXPKI->read_file ("$basedir/test-ca/cert.pem");
my $content = "This is for example a passprase.";
ok($passwd and $rsa and $cert);

## sign content

my $pkcs7 = OpenXPKI::Crypto::PKCS7->new (TOKEN => $token, CONTENT => $content);
my $sig = $pkcs7->sign (CERT      => $cert,
                        KEY       => $rsa,
                        PASSWD    => $passwd);
ok(1);
print STDERR "PKCS#7 signature: $sig\n" if ($ENV{DEBUG});

## encrypt content

$content = $pkcs7->encrypt (CERT      => $cert);
ok(1);
print STDERR "PKCS#7 encryption: $content\n" if ($ENV{DEBUG});

## decrypt content

$content = $pkcs7->decrypt (CERT   => $cert,
                            KEY    => $rsa,
                            PASSWD => $passwd);
ok(1);
print STDERR "PKCS#7 content: $content\n" if ($ENV{DEBUG});
ok ($content eq "This is for example a passprase.");

## verify signature

$pkcs7 = OpenXPKI::Crypto::PKCS7->new (TOKEN => $token, CONTENT => $content, PKCS7 => $sig);
my $result = $pkcs7->verify (
    CHAIN => [ $cacert ],
);
ok(1);
print STDERR "PKCS#7 verify: $result\n" if ($ENV{DEBUG});

## extract available chain from signature

$result = $pkcs7->get_chain();
ok(1);
print STDERR "PKCS#7 get_chain: ".scalar @{$result}."\n" if ($ENV{DEBUG});

## performance

my $items = 20;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    $pkcs7 = OpenXPKI::Crypto::PKCS7->new (TOKEN => $token, CONTENT => $content, PKCS7 => $sig);
    $pkcs7->verify(
        CHAIN => [ $cacert ],
    );
    $pkcs7->get_chain();
}
ok (1);
$result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result signatures/second (minimum: 1000 per minute)\n" if $ENV{VERBOSE};
#ok ($result > 17);
ok ($result);

}
}
1;

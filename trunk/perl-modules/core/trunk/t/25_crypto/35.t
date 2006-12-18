use strict;
use warnings;
use Test;
BEGIN { plan tests => 12 };

print STDERR "OpenXPKI::Crypto::PKCS7\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI qw (read_file);
use OpenXPKI::Crypto::PKCS7;
use Time::HiRes;

our $cache;
our $cacert;
our $basedir;
eval `cat t/25_crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "CA", 
    ID => "INTERNAL_CA_1", 
    PKI_REALM => "Test Root CA",
    CERTIFICATE => $cacert,
);
ok (1);

## load data

my $passwd = OpenXPKI->read_file ("$basedir/ca1/passwd.txt");
my $rsa    = OpenXPKI->read_file ("$basedir/ca1/rsa.pem");
my $cert   = OpenXPKI->read_file ("$basedir/ca1/cert.pem");
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
print STDERR " - $result signatures/second (minimum: 1000 per minute)\n";
#ok ($result > 17);
ok ($result);

1;

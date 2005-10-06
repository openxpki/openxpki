use strict;
use warnings;
use Test;
BEGIN { plan tests => 12 };

print STDERR "OpenXPKI::Crypto::PKCS7\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI qw (read_file);
use OpenXPKI::Crypto::PKCS7;
use Time::HiRes;

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
my $rsa    = OpenXPKI->read_file ("t/crypto/rsa.pem");
my $cert   = OpenXPKI->read_file ("t/crypto/cert.pem");
my $content = "This is for example a passprase.";
ok($passwd and $rsa and $cert);

## sign content

my $pkcs7 = OpenXPKI::Crypto::PKCS7->new (TOKEN => $token, CONTENT => $content);
my $sig = $pkcs7->sign (CERT      => $cert,
                        KEY       => $rsa,
                        PASSWD    => $passwd);
if ($sig)
{
    ok(1);
    print STDERR "PKCS#7 signature: $sig\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$pkcs7->errval()."\n";
}

## encrypt content

$content = $pkcs7->encrypt (CERT      => $cert);
if ($content)
{
    ok(1);
    print STDERR "PKCS#7 encryption: $content\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$pkcs7->errval()."\n";
}

## decrypt content

$content = $pkcs7->decrypt (CERT   => $cert,
                            KEY    => $rsa,
                            PASSWD => $passwd);
if ($content)
{
    ok(1);
    print STDERR "PKCS#7 content: $content\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$pkcs7->errval()."\n";
}
ok ($content eq "This is for example a passprase.");

## verify signature

$pkcs7 = OpenXPKI::Crypto::PKCS7->new (TOKEN => $token, CONTENT => $content, PKCS7 => $sig);
my $result = $pkcs7->verify ();
if ($result)
{
    ok(1);
    print STDERR "PKCS#7 verify: $result\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$pkcs7->errval()."\n";
}

## extract available chain from signature

$result = $pkcs7->get_chain();
if ($result)
{
    ok(1);
    print STDERR "PKCS#7 get_chain: ".scalar @{$result}."\n" if ($ENV{DEBUG});
} else {
    ok(0);
    print STDERR "Error: ".$pkcs7->errval()."\n";
}

## performance

my $items = 100;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    $pkcs7 = OpenXPKI::Crypto::PKCS7->new (TOKEN => $token, CONTENT => $content, PKCS7 => $sig);
    $pkcs7->verify();
    $pkcs7->get_chain();
}
ok (1);
$result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result signatures/second (minimum: 100 per second)\n";
ok ($result > 100);

1;

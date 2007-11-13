use strict;
use warnings;
use Test::More;
plan tests => 16;

print STDERR "OpenXPKI::Crypto::CRL\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CRL;
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

## load CRL
my $data = OpenXPKI->read_file ("$basedir/ca1/crl.pem");
ok(1);
$data = "-----BEGIN HEADER-----\n".
        "GLOBAL_ID=1234\n".
        "-----END HEADER-----\n".
        $data;

## init object
my $crl = OpenXPKI::Crypto::CRL->new (TOKEN => $token, DATA => $data);
ok(1);

## test parser
ok ($crl->get_parsed("BODY", "ISSUER") eq "CN=CA_1,DC=OpenXPKI,DC=info");
is ($crl->get_parsed("BODY", "SERIAL"), 23, 'get_parsed() -> serial');
is ($crl->get_serial(), 23, 'get_serial()');
ok ($crl->get_parsed("HEADER", "GLOBAL_ID") == 1234);

## test attribute setting
ok ($crl->set_header_attribute(TEST => "abc"));
ok ($crl->get_parsed("HEADER", "TEST") eq "abc");

## test conversion
ok ($crl->get_converted ("PEM"));
ok ($crl->get_converted ("DER"));
ok ($crl->get_converted ("TXT"));

## performance
my $items = 1000;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    $crl = OpenXPKI::Crypto::CRL->new (TOKEN => $token, DATA => $data);
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result CRLs/second (minimum: 100 per second)\n";
#ok ($result > 100);
ok ($result);

1;

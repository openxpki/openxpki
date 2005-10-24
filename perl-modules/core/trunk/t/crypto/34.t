use strict;
use warnings;
use Test;
BEGIN { plan tests => 16 };

print STDERR "OpenXPKI::Crypto::CRL\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CRL;
use Time::HiRes;

our $cache;
eval `cat t/crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (1);

## load CRL
my $data = OpenXPKI->read_file ("t/crypto/crl.pem");
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
ok ($crl->get_parsed("BODY", "SERIAL") == -1);
ok ($crl->get_serial() > 1128083416);
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
ok ($result > 100);

1;

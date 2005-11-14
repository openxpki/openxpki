use strict;
use warnings;
use Test;
BEGIN { plan tests => 15 };

print STDERR "OpenXPKI::Crypto::X509\n";

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::X509;
use Time::HiRes;

our $cache;
eval `cat t/crypto/common.pl`;

ok(1);

## parameter checks for TokenManager init

my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (TYPE => "CA", NAME => "INTERNAL_CA_1", PKI_REALM => "Test Root CA");
ok (1);

## load certificate
my $data = OpenXPKI->read_file ("t/crypto/cert.pem");
ok(1);
$data = "-----BEGIN HEADER-----\n".
           "ROLE=User\n".
           "-----END HEADER-----\n".
           $data;

## init object
my $cert = OpenXPKI::Crypto::X509->new (TOKEN => $token, DATA => $data);
ok(1);

## test parser
ok ($cert->get_parsed("BODY", "SUBJECT") eq "CN=John Doe,DC=OpenCA,DC=info");
ok ($cert->get_parsed("BODY", "KEYSIZE") == 1024);
ok ($cert->get_parsed("HEADER", "ROLE") eq "User");

## test attribute setting
ok ($cert->set_header_attribute(GLOBAL_ID => 1234));
ok ($cert->get_parsed("HEADER", "GLOBAL_ID") == 1234);

## test conversion
ok ($cert->get_converted ("PEM"));
ok ($cert->get_converted ("DER"));
ok ($cert->get_converted ("TXT"));

## performance
my $items = 1000;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    $cert = OpenXPKI::Crypto::X509->new (TOKEN => $token, DATA => $data);
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result certs/second (minimum: 100 per second)\n";
ok ($result > 100);

1;

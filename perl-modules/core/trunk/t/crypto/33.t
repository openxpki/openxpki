use strict;
use warnings;
use Test;
BEGIN { plan tests => 10 };

print STDERR "OpenXPKI::Crypto::CRR\n";

use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CRR;
use Time::HiRes;

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

## load CRR
my $data = "-----BEGIN HEADER-----\n".
           "SERIAL=1234\n".
           "REVOKED_CERTIFICATE_SERIAL=12\n".
           "-----END HEADER-----\n";

## init object
my $crr = OpenXPKI::Crypto::CRR->new (DATA => $data);
ok(1);

## test parser
ok ($crr->get_parsed("HEADER", "SERIAL") == 1234);
ok ($crr->get_parsed("HEADER", "REVOKED_CERTIFICATE_SERIAL") == 12);

## test attribute setting
ok ($crr->set_header_attribute(REASON => "Key compromised."));
ok ($crr->get_parsed("HEADER", "REASON") eq "Key compromised.");

## performance
my $items = 1000;
my $begin = [ Time::HiRes::gettimeofday() ];
for (my $i=0; $i<$items; $i++)
{
    $crr = OpenXPKI::Crypto::CRR->new (DATA => $data);
}
ok (1);
my $result = Time::HiRes::tv_interval( $begin, [Time::HiRes::gettimeofday()]);
$result = $items / $result;
$result =~ s/\..*$//;
print STDERR " - $result CRRs/second (minimum: 100 per second)\n";
ok ($result > 100);

1;

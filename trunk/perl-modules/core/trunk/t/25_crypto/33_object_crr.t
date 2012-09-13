use strict;
use warnings;
use Test::More;
use English;

BEGIN { 
    plan tests => 10 
};

print STDERR "OpenXPKI::Crypto::CRR\n" if $ENV{VERBOSE};

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CRR;
use Time::HiRes;

our $cache;
our $cacert;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 9 if $EVAL_ERROR;



## parameter checks for TokenManager init
my $mgmt = OpenXPKI::Crypto::TokenManager->new({'IGNORE_CHECK' => 1});
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
print STDERR " - $result CRRs/second (minimum: 100 per second)\n" if $ENV{VERBOSE};
#ok ($result > 100);
ok ($result);

}
1;

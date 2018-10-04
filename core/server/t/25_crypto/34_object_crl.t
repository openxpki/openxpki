use strict;
use warnings;
use Test::More;
use English;

plan tests => 16;

TODO: {
    todo_skip 'See Issue #188', 16;

print STDERR "OpenXPKI::Crypto::CRL\n" if $ENV{VERBOSE};

use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CRL;
use Time::HiRes;

our $cache;
our $cacert;
our $basedir;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 15 if $EVAL_ERROR;


## parameter checks for TokenManager init
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


## load CRL
my $data = OpenXPKI->read_file ("$basedir/test-ca/crl.pem");
ok(1);
$data = "-----BEGIN HEADER-----\n".
        "GLOBAL_ID=1234\n".
        "-----END HEADER-----\n".
        $data;

## init object
my $crl = OpenXPKI::Crypto::CRL->new (TOKEN => $token, DATA => $data);
ok(1);

## test parser
is ($crl->get_parsed("BODY", "ISSUER"), "DC=test,DC=openxpki,CN=test-ca");
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
print STDERR " - $result CRLs/second (minimum: 100 per second)\n" if $ENV{VERBOSE};
#ok ($result > 100);
ok ($result);

}
}
1;

use strict;
use warnings;

use Test::More;

plan tests => 8;

TODO: {
    todo_skip 'See Issue #188', 8;

use English;

use OpenXPKI::Crypto::TokenManager;

our $cache;
our $cacert;
eval `cat t/25_crypto/common.pl`;

is($EVAL_ERROR, '', 'common.pl evaluated correctly');

SKIP: {
    skip 'crypt init failed', 7 if $EVAL_ERROR;


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

open my $CACERT1, '<', 't/25_crypto/test-ca/cacert.pem';
my $cacert1 = do {
    local $INPUT_RECORD_SEPARATOR;
    <$CACERT1>;
};
close($CACERT1);
ok($cacert1, 'Read in CA certificate 1');

open my $CERT, '<', 't/25_crypto/test-ca/cert.pem';
my $cert = do {
    local $INPUT_RECORD_SEPARATOR;
    <$CERT>;
};
ok($cert, 'Read in end-entity certificate');

my $result = $token->command({
    COMMAND            => 'is_issuer',
    CERT               => $cert,
    'POTENTIAL_ISSUER' => $cacert1,
});

ok($result, 'end-entity certificate is issued by CA 1');

$result = $token->command({
    COMMAND            => 'is_issuer',
    CERT               => $cacert1,
    'POTENTIAL_ISSUER' => $cert,
});

ok(! $result, 'CA 1 is not issued by end-entity cert');

$result = $token->command({
    COMMAND            => 'is_issuer',
    CERT               => $cacert1,
    'POTENTIAL_ISSUER' => $cacert1,
});

ok($result, 'CA 1 is self-signed');

}
}
1;

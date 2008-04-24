use strict;
use warnings;

use Test::More;
plan tests => 7;

use English;

use OpenXPKI::Crypto::TokenManager;

our $cache;
eval `cat t/25_crypto/common.pl`;

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok(defined $mgmt, 'TokenManager defined');

## parameter checks for get_token

my $token = $mgmt->get_token (
    TYPE => "DEFAULT", 
    PKI_REALM => "Test Root CA");
ok(defined $token, 'Default token defined');

open my $CACERT1, '<', 't/25_crypto/ca1/cacert.pem';
my $cacert1 = do {
    local $INPUT_RECORD_SEPARATOR;
    <$CACERT1>;
};
close($CACERT1);
ok($cacert1, 'Read in CA certificate 1');

open my $CERT, '<', 't/25_crypto/ca1/cert.pem';
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


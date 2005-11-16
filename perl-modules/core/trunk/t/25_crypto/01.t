use strict;
use warnings;
use Test;
BEGIN { plan tests => 4 };

print STDERR "OpenXPKI::Crypto::TokenManager\n";

use OpenXPKI::Crypto::TokenManager;

our $cache;
eval `cat t/25_crypto/common.pl`;

ok(1);

eval
{
    OpenXPKI::Crypto::TokenManager->new (DEBUG => 0);
};
ok (OpenXPKI::Exception->caught());
my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (TYPE => "CA", NAME => "INTERNAL_CA_1", PKI_REALM => "Test Root CA");
ok (1);

1;

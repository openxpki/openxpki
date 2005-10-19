use strict;
use warnings;
use Test;
BEGIN { plan tests => 4 };

print STDERR "OpenXPKI::Crypto::TokenManager\n";

use OpenXPKI;
use OpenXPKI::XML::Cache;
use OpenXPKI::Crypto::TokenManager;

our $cache;
eval `cat t/crypto/common.pl`;

ok(1);

eval
{
    OpenXPKI::Crypto::TokenManager->new (DEBUG => 0);
};
ok (OpenXPKI::Exception->caught());
my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");
ok (1);

1;

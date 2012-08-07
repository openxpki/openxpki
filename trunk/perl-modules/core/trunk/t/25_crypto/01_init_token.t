use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 3;

diag "OpenXPKI::Crypto::TokenManager\n" if $ENV{VERBOSE};

use OpenXPKI::Crypto::TokenManager;

eval `cat t/25_crypto/common.pl`;

is($@, '', 'seems that init succeeded');

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok ($mgmt, 'Create OpenXPKI::Crypto::TokenManager instance');

## parameter checks for get_token

my $token = $mgmt->get_token ( {
   TYPE => "certsign", 
   NAME => "server-ca"
   }
);
ok (defined $token, 'Parameter checks for get_token');

1;

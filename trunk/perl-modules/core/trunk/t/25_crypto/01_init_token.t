use strict;
use warnings;
use Data::Dumper;
use Test;
BEGIN { plan tests => 3 };

print STDERR "OpenXPKI::Crypto::TokenManager\n";

use OpenXPKI::Crypto::TokenManager;

eval `cat t/25_crypto/common.pl`;

is($@, '', 'seems that init succeeded');

my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
ok (1);

## parameter checks for get_token

my $token = $mgmt->get_token ( {
   TYPE => "certsign", 
   NAME => "server-ca"
   }
);
ok (defined $token);

1;

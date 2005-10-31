
use strict;
use warnings;

## prepare needed crypto token

use OpenXPKI::Crypto::TokenManager;
our $cache;
eval `cat t/crypto/common.pl`;
my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CACHE => $cache);
my $token = $mgmt->get_token (NAME => "INTERNAL_CA_1", CA_GROUP => "CA_GROUP_1");

## prepare database configuration

our %config = (
              DEBUG  => 0,
              TYPE   => "SQLite",
              NAME   => "t/dbi/sqlite.db",
              CRYPTO => $token,
             );


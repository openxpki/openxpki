
use strict;
use warnings;

## prepare needed crypto token

use OpenXPKI::Crypto::TokenManager;
our $cache;
require 't/crypto/common.pl';
my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
my $token = $mgmt->get_token (TYPE => "DEFAULT", NAME => "default", PKI_REALM => "Test Root CA");

## prepare database configuration

our %config = (
              DEBUG  => 0,
              TYPE   => "SQLite",
              NAME   => "t/dbi/sqlite.db",
              CRYPTO => $token,
             );

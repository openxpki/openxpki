use strict;
use warnings;

## init crypto token

use OpenXPKI::Crypto::TokenManager;
our $cache;
require 't/25_crypto/common.pl';
my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
my $token = $mgmt->get_token (TYPE => "DEFAULT", NAME => "default", PKI_REALM => "Test Root CA");
ok(1);

## init database module

use OpenXPKI::Server::DBI;
my %config = (
              DEBUG  => 0,
              TYPE   => "SQLite",
              NAME   => "t/28_log/sqlite.db",
              CRYPTO => $token,
             );
our $dbi = OpenXPKI::Server::DBI->new (%config);
ok($dbi->connect());


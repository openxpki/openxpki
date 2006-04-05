
use strict;
use warnings;

## prepare needed crypto token

use OpenXPKI::Crypto::TokenManager;
our $cache;
require 't/25_crypto/common.pl';
my $mgmt = OpenXPKI::Crypto::TokenManager->new ();
our $token = $mgmt->get_token (
    TYPE => "DEFAULT", 
    ID => "default", 
    PKI_REALM => "Test Root CA");
ok($token);

## prepare log system

use OpenXPKI::Server::Log;
my $log = OpenXPKI::Server::Log->new (CONFIG => "t/28_log/log.conf");
ok($log);

## prepare database configuration

use OpenXPKI::Server::DBI;
our %config = (
              TYPE   => "SQLite",
              NAME   => "t/30_dbi/sqlite.db",
              LOG    => $log
             );
our $dbi = OpenXPKI::Server::DBI->new (%config);

ok($dbi and ref $dbi);

ok($dbi->connect());

ok ($dbi->set_crypto ($token));



use strict;
use warnings;

## prepare needed crypto token

use OpenXPKI::Crypto::TokenManager;
our $cache;
require 't/25_crypto/common.pl';
my $mgmt = OpenXPKI::Crypto::TokenManager->new('IGNORE_CHECK' => 1);
our $token = $mgmt->get_token (
    TYPE => "DEFAULT", 
    ID => "default", 
    PKI_REALM => "Test Root CA");
ok($token, 'Default token initialized');

## prepare log system

use OpenXPKI::Server::Log;
my $log = OpenXPKI::Server::Log->new (CONFIG => "t/28_log/log.conf");
ok($log, 'Log object initialized');

## prepare database configuration

use OpenXPKI::Server::DBI;
our %config = (
              TYPE   => "SQLite",
              NAME   => "t/30_dbi/sqlite.db",
              LOG    => $log
             );
our $dbi = OpenXPKI::Server::DBI->new (%config);

ok($dbi && ref $dbi, 'DBI instantiation');

ok($dbi->connect(), 'DBI connect');

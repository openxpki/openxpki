
use strict;
use warnings;

## prepare needed crypto token

use OpenXPKI::Crypto::TokenManager;
our $cache;
require 't/25_crypto/common.pl';
my $mgmt = OpenXPKI::Crypto::TokenManager->new (DEBUG => 0, CONFIG => $cache);
our $token = $mgmt->get_token (TYPE => "DEFAULT", NAME => "default", PKI_REALM => "Test Root CA");

## prepare database configuration

use OpenXPKI::Server::DBI;
our %config = (
              DEBUG  => 0,
              TYPE   => "SQLite",
              NAME   => "t/30_dbi/sqlite.db",
              CRYPTO => $token,
             );
our $dbi = OpenXPKI::Server::DBI->new (%config);

ok($dbi and ref $dbi);

ok($dbi->connect());

## prepare log system

use OpenXPKI::Server::Log;
my $log = OpenXPKI::Server::Log->new (CONFIG => "t/28_log/log.conf",
                                      DBI    => $dbi);
ok($log);

ok ($dbi->set_log_ref ($log));



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
if ($ENV{'OPENXPKI_TEST_DB'} eq 'MySQL') {
    my $username = 'openxpki_test';
    my $password = 'openxpki_test'; # yay, a default password :-)
    my $name     = 'openxpki_test';
    # make it possible to override test settings using environment variables
    if (exists $ENV{'OPENXPKI_TEST_DB_MYSQL_USERNAME'}) {
        $username = $ENV{'OPENXPKI_TEST_DB_MYSQL_USERNAME'};
    }
    if (exists $ENV{'OPENXPKI_TEST_DB_MYSQL_PASSWORD'}) {
        $password = $ENV{'OPENXPKI_TEST_DB_MYSQL_PASSWORD'};
    }
    if (exists $ENV{'OPENXPKI_TEST_DB_MYSQL_DATABASE'}) {
        $name = $ENV{'OPENXPKI_TEST_DB_MYSQL_DATABASE'};
    }
    %config = (
        TYPE   => 'MySQL',
        NAME   => $name,
        USER   => $username,
        PASSWD => $password,
        LOG    => $log,
    );
}
our $dbi = OpenXPKI::Server::DBI->new (%config);

ok($dbi && ref $dbi, 'DBI instantiation');

ok($dbi->connect(), 'DBI connect');

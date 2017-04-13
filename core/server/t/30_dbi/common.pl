
use strict;
use warnings;

## prepare needed crypto token

# create database openxpki;
# GRANT ALL PRIVILEGES ON openxpki.* TO 'openxpki'@'localhost' IDENTIFIED BY 'openxpki' WITH GRANT OPTION; 
# flush privileges;
 
our $cache;

## prepare log system

use OpenXPKI::Server::Log;
my $log = OpenXPKI::Server::Log->new (CONFIG => "t/28_log/log4perl.conf");
ok($log, 'Log object initialized');

## prepare database configuration

use OpenXPKI::Server::Database;
use OpenXPKI::Config::Test;
use OpenXPKI::Server::Log::NOOP;

my $config = OpenXPKI::Config::Test->new();
my %params = (LOG => $log);

my $db_config = $config->get_hash('system.database.main');
foreach my $key ( qw(type name namespace host port user passwd) ) {
    ##! 16: "dbi: $key => " . $db_config->{$key}
    $params{$key} = $db_config->{$key}; 
}    
 
our $dbi = OpenXPKI::Server::Database->new (%params);

ok($dbi && ref $dbi, 'DBI instantiation');

ok($dbi->select('SELECT 1 FROM DUAL'), 'DBI connected');

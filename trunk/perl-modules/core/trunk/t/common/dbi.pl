use strict;
use warnings;

use OpenXPKI::Server::DBI;
use OpenXPKI::Config::Test;
use OpenXPKI::Server::Log::NOOP;

my $config = OpenXPKI::Config::Test->new();


use OpenXPKI::Server::Log;
my $log = OpenXPKI::Server::Log::NOOP->new();

my %params = (LOG => $log);

my $db_config = $config->get_hash('system.database.main');
foreach my $key qw(type name namespace host port user passwd) {
    ##! 16: "dbi: $key => " . $db_config->{$key}
    $params{uc($key)} = $db_config->{$key}; 
}    

our $dbi = OpenXPKI::Server::DBI->new (%params);

ok($dbi && ref $dbi, 'DBI instantiation');

ok($dbi->connect(), 'DBI connect');

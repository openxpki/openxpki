use strict;
use warnings;

## init logging module

use OpenXPKI::Server::Log;
our $log = OpenXPKI::Server::Log->new (CONFIG => "t/28_log/log.conf");
ok($log);

## init database module

use OpenXPKI::Server::DBI;
my %config = (
              TYPE   => "SQLite",
              NAME   => "t/28_log/sqlite.db",
              LOG    => $log
             );
our $dbi = OpenXPKI::Server::DBI->new (%config);
ok($dbi->connect());


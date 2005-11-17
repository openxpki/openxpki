use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 6 };

print STDERR "OpenXPKI::Server::Log: interface of log function\n";

use OpenXPKI::Server::Log;

ok(1);

our $dbi;
require 't/28_log/common.pl';

my $log = OpenXPKI::Server::Log->new (CONFIG => "t/28_log/log.conf",
                                      DBI    => $dbi);

ok($log);

ok (not defined eval {$log->log ()} and $EVAL_ERROR);

ok ($log->log (FACILITY => "auth",
               PRIORITY => "info",
               MESSAGE  => "Test."));

1;

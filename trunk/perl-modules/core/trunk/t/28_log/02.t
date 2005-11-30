use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 4 };

print STDERR "OpenXPKI::Server::Log: interface of log function\n";

use OpenXPKI::Server::Log;

our $log;
our $dbi;
require 't/28_log/common.pl';

ok (not defined eval {$log->log ()} and $EVAL_ERROR);

ok ($log->log (FACILITY => "auth",
               PRIORITY => "info",
               MESSAGE  => "Test."));

1;

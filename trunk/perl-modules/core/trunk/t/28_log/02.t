use strict;
use warnings;
use English;
use Test::More;
plan tests => 6;

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

diag "OpenXPKI::Server::Log: interface of log function\n";
use OpenXPKI::Server::Log;

our $log;
our $dbi;
eval {
require 't/28_log/common.pl';
};
is ($EVAL_ERROR, '', 'common.pl evaluation');

eval {
    $log->log();
};
ok ($EVAL_ERROR, 'Empty log call throws error');

ok ($log->log (FACILITY => "auth",
               PRIORITY => "info",
               MESSAGE  => "Test."), 'Test message');

ok (-s 't/28_log/openxpki.log', 'Log file exists and is non-empty');

1;

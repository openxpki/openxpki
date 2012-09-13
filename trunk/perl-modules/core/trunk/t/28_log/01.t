use strict;
use warnings;
use English;
use Test::More;
plan tests => 6;

use OpenXPKI::Debug;
if ($ENV{DEBUG_LEVEL}) {
    $OpenXPKI::Debug::LEVEL{'.*'} = $ENV{DEBUG_LEVEL};
}

diag "OpenXPKI::Server::Log: interface of log function\n" if $ENV{VERBOSE};
use OpenXPKI::Server::Log;

my $filename = "t/28_log/openxpki.log";
ok (!-e $filename || unlink ($filename), 'Remove old logfile if any');

my $log = OpenXPKI::Server::Log->new( CONFIG => 't/28_log/log4perl.conf' );

# Not logged 
ok (! $log->log (FACILITY => "auth",
               PRIORITY => "debug",
               MESSAGE  => "Test."), 'Test message');

ok (! -s 't/28_log/openxpki.log', 'Log file has zero size');

# error
eval {
    $log->log();
};
ok ($EVAL_ERROR, 'Empty log call throws error');

# loggged

ok ($log->log (FACILITY => "auth",
               PRIORITY => "info",
               MESSAGE  => "Test."), 'Test message');

ok (-s 't/28_log/openxpki.log', 'Log file exists and is non-empty');

1;

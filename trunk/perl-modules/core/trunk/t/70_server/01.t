use strict;
use warnings;
use English;
use Test::More;
plan tests => 12;

diag "OpenXPKI::Server\n";

use OpenXPKI::Server;

`cp t/30_dbi/sqlite.db t/30_dbi/sqlite.db._backend_`;
is($CHILD_ERROR, 0, 'Copying database');

`cp t/30_dbi/sqlite.db t/30_dbi/sqlite.db._log_`;
is($CHILD_ERROR, 0, 'Copying database');

foreach my $mode ('debug', '')
{
    diag "Starting server in debug mode ...\n"
        if ($mode eq "debug");

    my @cmd = qw( perl
                  t/70_server/startup.pl );
    my $sleep = 5;
    if ($mode eq 'debug') {
        push @cmd, '--debug 128';
        $sleep += 10;
    }

    ok(system(@cmd) == 0, 'Server started without an error code');
    diag "Waiting $sleep seconds for starting server ...\n";
    sleep($sleep);

    if (not -e 't/pid') {
        diag "Waiting 5 additional seconds to support very slow machines ...\n";
        sleep 5;
    }
    ok(-e "t/pid", 'PID file exists');
    ok(-e "t/socket", 'Socket file exists');

    ## should we check here that the server is really running?

    my $pid = `cat t/pid`;
    ok($pid =~ m{ \d+ }xs, 'PID file contains a number');

    my $ret = `kill $pid`;
    ok(! $?, 'Server termination') or diag "Error: ".$?."(".$@.")\n";
}

1;

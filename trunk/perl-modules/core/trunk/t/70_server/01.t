use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 11 };

print STDERR "OpenXPKI::Server\n";

use OpenXPKI::Server;
ok(1);

foreach my $mode ('debug', '')
{
    print STDERR "Starting server in debug mode ...\n"
        if ($mode eq "debug");

    my @cmd = qw( perl
                  t/70_server/startup.pl );
    my $sleep = 5;
    if ($mode eq 'debug') {
	push @cmd, '--debug';
	$sleep += 10;
    }

    ok(system(@cmd) == 0);
    print STDERR "Waiting $sleep seconds for starting server ...\n";
    sleep($sleep);

    if (not -e 't/pid')
    {
        print STDERR "Waiting 5 additional seconds to support very slow machines ...\n";
        sleep 5;
    }
    ok(-e "t/pid");
    ok(-e "t/socket");

    ## should we check here that the server is really running?

    my $pid = `cat t/pid`;
    ok($pid =~ m{ \d+ }xs);

    my $ret = `kill $pid`;
    if ($?)
    {
        ok(0);
        print STDERR "Error: ".$?."(".$@.")\n";
    } else {
        ok(1);
        print STDERR "Server terminated correctly.\n";
    }
}

1;

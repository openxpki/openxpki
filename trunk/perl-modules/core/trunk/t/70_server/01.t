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
    my $pid = fork();
    if ($pid)
    {
        my $sleep = 5;
           $sleep += 10 if ($mode eq 'debug');
        print STDERR "Waiting $sleep seconds for starting server ...\n";
        sleep $sleep;
    } else {
        my $options  = '';
           $options .= '--debug' if ($mode eq 'debug');
        my $ret = `perl t/70_server/startup.pl $options 2>&1 &`;
        print STDERR $ret."\n" if ($CHILD_ERROR);
        exit 1;
    }

    ok(1);
    ok("t/pid");
    ok("t/socket");

    ## should we check here that the server is really running?

    $pid = `cat t/pid`;
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

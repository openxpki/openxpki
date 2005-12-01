use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 7 };

print STDERR "OpenXPKI::Server\n";

use OpenXPKI::Server;
ok(1);

## fix the configuration file if needed
require "t/70_server/fix_config.pl";
ok(1);

my $pid = fork();
if ($pid)
{
    print STDERR "Waiting 5 seconds for starting server ...\n";
    sleep 5;
} else {
    my $ret = `perl t/70_server/startup.pl 2>&1 &`;
    print STDERR $ret."\n" if ($CHILD_ERROR);
    exit 1;
}

ok(1);
ok("t/pid");
ok("t/socket");

## should we check here that the server is really running?

$pid = `cat t/pid`;
ok($pid);

my $ret = `kill $pid`;
if ($?)
{
    ok(0);
    print STDERR "Error: ".$?."(".$@.")\n";
} else {
    ok(1);
}

1;

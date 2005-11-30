use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 6 };

print STDERR "OpenXPKI::Server\n";

my $check_user = "TRUE";
if ($check_user eq "TRUE")
{
    my @pwentry = getpwuid ($UID);
    if ($pwentry[0] ne "root")
    {
        ok(0);
        print STDERR "These tests can only be performed by root.\n";
        print STDERR "The tests change the UID and GID of the process.\n";
        print STDERR "Please deactivate this check ".
                     "if you use the actual user and group in t/config.xml.\n";
        exit 1;
    }
}
ok(1);

my $pid = fork();
if ($pid)
{
    print STDERR " Waiting 5 seconds for starting server ...";
    sleep 5;
    print STDERR "OK\n";
} else {
    my $ret = `perl t/70_server/startup.pl 2>&1 &`;
    print STDERR $ret."\n" if ($?);
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

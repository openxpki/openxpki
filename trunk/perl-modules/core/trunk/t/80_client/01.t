use strict;
use warnings;
use English;
use Test;
BEGIN { plan tests => 8 };

print STDERR "OpenXPKI::Client::CLI\n";

use OpenXPKI::Client::CLI;
ok(1);

my $mode = 'debug'; ## here you can add 'debug'
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

ok(-f "t/pid");
ok(-S "t/socket");

$pid = `cat t/pid`;
ok($pid);

## first initial client test
execute_test
(
    "perl t/80_client/cli.pl 1>t/80_client/cli.stdout 2>t/80_client/cli.stderr <<EOF\n".
    "YES\n". ## new session
    ## if there is only one PKI realm then it will be detected by the server
    ## "0\n".   ## PKI realm
    "1\n".   ## anonymous authentication
    "EOF"
);

## stop server
my $ret = `kill $pid`;
if ($?)
{
    ok(0);
    print STDERR "Error: ".$?."(".$@." - $ret)\n";
} else {
    ok(1);
    print STDERR "Server terminated correctly.\n";
}

sub execute_test
{
    my $cmd = shift;

    `$cmd`;
    if ($?)
    {
        ok(0);
        print STDERR "Client error: ".$?."(".$@.")\n";
    } else {
        ok(1);
    }

    ## detect exceptions
    my $ret = `grep -i EXCEPTION t/80_client/cli.stderr`;
       $ret =~ s/^DEBUGGING.*$//img;
    if ($ret =~ /EXCEPTION/i)
    {
        print STDERR "Error log contains an exception.\n";
        ok(0);
    } else {
        ok(1);
    }

    ## check the logout
    $ret = `grep I18N_OPENXPKI_CLIENT_CLI_DESTROY_LOGOUT_SUCCESSFUL t/80_client/cli.stdout`;
    if ($ret =~ /I18N_OPENXPKI_CLIENT_CLI_DESTROY_LOGOUT_SUCCESSFUL/)
    {
        ok(1);
    } else {
        print STDERR "Session was not cleanly terminated.\n";
        ok(0);
    }

    return 1;
}

1;

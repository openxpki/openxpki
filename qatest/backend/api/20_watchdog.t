#!/usr/bin/perl

use strict;
use warnings;

use lib qw(../../lib);

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

our %cfg = ();
my $testcfg = new TestCfg;
$testcfg->read_config_path( 'api.cfg', \%cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg{instance}{socketfile},
    realm => $cfg{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 4 );

# Login to use socket
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

$test->runcmd('control_watchdog', { ACTION => 'stop' });
$test->is($test->get_msg->{COMMAND}, 'control_watchdog');

$test->runcmd('control_watchdog', { ACTION => 'status' });
$test->is($test->get_msg->{PARAMS}->{children},0);

$test->runcmd('control_watchdog', { ACTION => 'start' });

$test->runcmd('control_watchdog', { ACTION => 'status' });
$test->ok(@{$test->get_msg->{PARAMS}->{pid}} > 0);

$test->disconnect();
$test->diag("done");
#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use Carp;
use English;
use Data::Dumper;
use File::Basename;
use FindBin qw( $Bin );

# CPAN modules
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

# Project modules
use lib "$Bin/../../lib";
use OpenXPKI::Test::More;
use TestCfg;

#
# Init client
#
our $cfg = {};
TestCfg->new->read_config_path( 'api.cfg', $cfg, dirname($0) );

my $test = OpenXPKI::Test::More->new({
    socketfile => $cfg->{instance}{socketfile},
    realm => $cfg->{instance}{realm},
}) or die "Error creating new test instance: $@";

$test->set_verbose($cfg->{instance}{verbose});
$test->plan( tests => 4 );

$test->connect_ok(
    user => $cfg->{operator}{name},
    password => $cfg->{operator}{password},
) or die "Error - connect failed: $@";

#
# Tests
#
$test->runcmd('control_watchdog', { ACTION => 'stop' });
$test->is($test->get_msg->{COMMAND}, 'control_watchdog', "Correct command");

my $MAX_WAIT = 10;
my $tick = 0;
while ($tick < $MAX_WAIT) {
    $test->runcmd('control_watchdog', { ACTION => 'status' });
    last if $test->get_msg->{PARAMS}->{children} == 0;
    $tick++;
    sleep 1;
}
$test->is($test->get_msg->{PARAMS}->{children}, 0, "Stop all child processes");

$test->runcmd('control_watchdog', { ACTION => 'start' });

$test->runcmd('control_watchdog', { ACTION => 'status' });
$test->ok(@{$test->get_msg->{PARAMS}->{pid}} > 0, "Create child processes");

$test->disconnect();

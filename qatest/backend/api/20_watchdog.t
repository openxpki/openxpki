#!/usr/bin/perl

use strict;
use warnings;

use lib qw(
  /usr/lib/perl5/ 
  ../../lib
);

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( 'api.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 4 );
  
# Login to use socket
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{password},
) or die "Error - connect failed: $@";

my $res = $test->get_client()->send_receive_command_msg( 'control_watchdog' , { ACTION => 'stop' } );
$test->is($res->{COMMAND}, 'control_watchdog');

$res = $test->get_client()->send_receive_command_msg( 'control_watchdog' , { ACTION => 'status' } );
$test->is($res->{PARAMS}->{children},0);

$res = $test->get_client()->send_receive_command_msg( 'control_watchdog' , { ACTION => 'start' } );

$res = $test->get_client()->send_receive_command_msg( 'control_watchdog' , { ACTION => 'status' } );
$test->ok(@{$res->{PARAMS}->{pid}} > 0);

$test->disconnect();
$test->diag("done");  
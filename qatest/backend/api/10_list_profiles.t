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

my $res = $test->get_client()->send_receive_command_msg( 'get_cert_subject_profiles' , { PROFILE => 'I18N_OPENXPKI_PROFILE_TLS_SERVER' } );

my @styles = sort keys %{$res->{PARAMS}};

$test->is( scalar @styles, 2 );
$test->is( $styles[0], '00_basic_style' );
$test->ok( $res->{PARAMS}->{ $styles[0] }->{LABEL} );  

$test->disconnect();
  
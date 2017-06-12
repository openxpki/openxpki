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
use File::Slurp;
use Digest::SHA qw(sha1_hex);

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '5x_personalize.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 10 );

$test->connect_ok( %{$cfg{auth}} ) or die "Error - connect failed: $@";
	
$test->create_ok( 'sc_fetch_puk' , { token_id => $cfg{carddata}{token_id}  }, 'Create SCv4 PUK Workflow')
 or die "Workflow Create failed: $@";
 
$test->state_is('MAIN');
    
$test->param_like('_puk','/ARRAY.*/'); 
 
$test->execute_ok('scfp_ack_fetch_puk') || die "Error acknowledge puk";
   
$test->state_is('SUCCESS');
 

$test->create_ok( 'sc_fetch_puk' , { token_id => $cfg{carddata}{token_id}  }, 'Create SCv4 PUK Workflow / abort')
 or die "Workflow Create failed: $@";

$test->state_is('MAIN');

$test->execute_ok('scfp_puk_fetch_err', { error_reason => 'failed for testing' }) || die "Error acknowledge puk";
   
$test->state_is('FAILURE');

$test->disconnect();

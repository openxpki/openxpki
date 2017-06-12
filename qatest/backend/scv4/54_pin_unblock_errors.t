#!/usr/bin/perl
#

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


use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '5x_personalize.cfg', \%cfg, @cfgpath );

my $ser = OpenXPKI::Serialization::Simple->new();

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 15 );
    
$test->connect_ok( %{$cfg{auth}} ) or die "Error - connect failed: $@";

my %wfparam = (                
    token_id =>  $cfg{carddata}{token_id}        
);      
    
$test->create_ok( 'sc_pin_unblock' , \%wfparam, 'Create PIN Unblock Workflow')
 or die "Workflow Create failed: $@";
 
$test->state_is('HAVE_TOKEN_OWNER'); 
 
$test->execute_ok('scunblock_store_auth_ids', {  auth1_id => $cfg{unblock}{auth1}, auth2_id => $cfg{unblock}{auth2} });
  
$test->state_is('PEND_ACT_CODE'); 

$test->disconnect();
 
# Login with auth1 and generate code
$test->connect_ok(
    user => $cfg{unblock}{auth1},
    stack => 'User',
) or die "Error - connect failed: $@";
 
$test->execute_ok('scunblock_generate_activation_code'); 
$test->param_like('_password', "/[a-zA-Z]+ [a-zA-Z]+/");

$test->disconnect();

# Login with auth2 and generate code
$test->connect_ok(
    user => $cfg{unblock}{auth2},
    stack  => 'User',
) or die "Error - connect failed: $@";
 
$test->execute_ok('scunblock_generate_activation_code'); 
$test->param_like('_password', "/[a-zA-Z]+ [a-zA-Z]+/");

$test->disconnect();

   
$test->connect_ok( %{$cfg{auth}} ) or die "Error - connect failed: $@";

$test->execute_ok('scunblock_post_codes', {  _auth1_code => 'wrong', _auth2_code => 'code'});

# Wrong Codes - should be back 
$test->state('PEND_PIN_CHANGE');

$test->execute_ok('scunblock_post_codes', {  _auth1_code => 'wrong', _auth2_code => 'code'});
$test->execute_ok('scunblock_post_codes', {  _auth1_code => 'wrong', _auth2_code => 'code'});

# After 3 failures the workflow should stop
$test->state('FAILURE');


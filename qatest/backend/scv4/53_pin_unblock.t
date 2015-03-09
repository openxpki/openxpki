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

$test->plan( tests => 21 );
   
$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{password},
) or die "Error - connect failed: $@";
  
my %wfparam = (                
    token_id =>  $cfg{carddata}{token_id}        
);      
    
$test->create_ok( 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK' , \%wfparam, 'Create PIN Unblock Workflow')
 or die "Workflow Create failed: $@";
 
$test->state_is('HAVE_TOKEN_OWNER'); 
 
$test->execute_ok('scunblock_store_auth_ids', {  auth1_id => $cfg{unblock}{auth1}, auth2_id => $cfg{unblock}{auth2} });
  
$test->state_is('PEND_ACT_CODE'); 

$test->disconnect();
 
# Login with auth1 and generate code
$test->connect_ok(
    user => $cfg{unblock}{auth1},
    password => 'User',
) or die "Error - connect failed: $@";
 
$test->execute_ok('scunblock_generate_activation_code');
$test->param_like('_password', "/[a-zA-Z]+ [a-zA-Z]+/");
my $auth1_password = $test->param('_password');
$test->diag("Auth1 Password is ". $auth1_password );

$test->disconnect();

# Login with auth2 and generate code
$test->connect_ok(
    user => $cfg{unblock}{auth2},
    password => 'User',
) or die "Error - connect failed: $@";
 
$test->execute_ok('scunblock_generate_activation_code'); 
$test->param_like('_password', "/[a-zA-Z]+ [a-zA-Z]+/");
my $auth2_password = $test->param('_password');
$test->diag("Auth2 Password is ". $auth2_password );

$test->disconnect();

# Login with auth1 again and regenerate code
$test->connect_ok(
    user => $cfg{unblock}{auth1},
    password => 'User',
) or die "Error - connect failed: $@";
 
$test->execute_ok('scunblock_generate_activation_code'); 
my $new_auth1_password = $test->param('_password');
$test->ok($new_auth1_password);
$test->diag("Regenerated Auth1 Password is ". $new_auth1_password);

$test->ok($new_auth1_password ne $auth1_password);

$test->disconnect();
   
$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{password},
) or die "Error - connect failed: $@";

$test->execute_ok('scunblock_post_codes', {  _auth1_code => $new_auth1_password, _auth2_code => $auth2_password});

$test->execute_ok('scunblock_fetch_puk');
my $puk = $test->param('_puk');
$test->ok($puk);

$test->diag('PUK is ' . $puk);

$test->execute_ok('scunblock_write_pin_ok');

$test->state_is('SUCCESS');
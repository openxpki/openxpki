#!/usr/bin/perl
#

# The Script is tailored to a special test case, it will proceed but
# show errors if the prerequs are not matched
#
# 1) If you test with a card with chip_id, you need to clear the 
#    recorded assignment in the datapool first
# 2) The user should have more than one assigned login, the test
#    selects the first one
# 3) The scripts needs a dummy csr to post - this is created on the first 
#    run at "sctest.csr" by calling openssl. You need the openssl binary
#    in the path and write access to the current directory
# 4) Set the states CERT_PUBLISH_CHECK, CERTS_PUBLISHED to not autorun
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

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '5x_personalize.cfg', \%cfg, @cfgpath );


-f 'sctest.csr' || `openssl req -new -batch -nodes -keyout sctest.key  -out sctest.csr`; 

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 24 );


$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";

my $ser = OpenXPKI::Serialization::Simple->new();

my %wfparam = (        
        user_id => $cfg{carddata}{frontend_user},
        token_id => $cfg{carddata}{token_id},
        chip_id => $cfg{carddata}{chip_id},
        certs_on_card => '',
);      

	
$test->create_ok( 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V4' , \%wfparam, 'Create SCv4 Test Workflow')
 or die "Workflow Create failed: $@";

 
# Fetch PUK
if ($test->state_is('PUK_TO_INSTALL')) {
    $test->execute_ok('scpers_fetch_puk');
    $test->state_is('PUK_TO_INSTALL');
    $test->param_like('_puk','/ARRAY.*/');
    $test->execute_ok('scpers_puk_write_ok'); 
}

$test->state_is('NEED_NON_ESCROW_CSR');
$test->execute_ok('scpers_fetch_puk');
$test->state_is('NEED_NON_ESCROW_CSR');
$test->param_like('_puk','/ARRAY.*/');

open PKCS10, "<sctest.csr";
my @lines = <PKCS10>;
close PKCS10;
 
$test->execute_ok('scpers_post_non_escrow_csr', { pkcs10 => join ("", @lines), keyid => 13 });

if ($test->state_is('POLICY_INPUT_REQUIRED')) {
  $test->param_is('policy_input_required','login_ids', 'Check what to do');
  $test->param_is('policy_max_login_ids','1', 'Read Policy Setting (max_login_ids)');

  my $login = shift @{ $ser->deserialize($test->param('policy_login_ids'))};

  $test->execute_ok('scpers_apply_csr_policy', { 'login_ids' => $ser->serialize( [ $login ] ) });
}

my @certs;
# CSR done - Installs
$test->state_is('PKCS12_TO_INSTALL');
$test->execute_ok('scpers_refetch_p12');

#$test->param_isnt('_keypassword','', 'Check for keypassword');
#$test->param_isnt('_password','', 'Check for password');
$test->param_isnt('_pkcs12base64','', 'Check for P12'); 
push @certs, $test->param('certificate');

open PKCS10, ">sctest.p12";
print PKCS10 $test->param('_pkcs12base64');
close PKCS10;

$test->execute_ok('scpers_cert_inst_ok');


$test->state_is('CERT_TO_INSTALL');
$test->param_is('cert_install_type','x509', 'Check for x509 type parameter');
$test->param_like('certificate','/-----BEGIN CERTIFICATE.*/','Check for PEM certificate');
push @certs, $test->param('certificate');             
$test->execute_ok('scpers_cert_inst_ok');


#$test->state_is('CERT_PUBLISH_CHECK');
#$test->execute_ok('scpers_queue_certs_for_publication');

#$test->state_is('CERTS_PUBLISHED');
#$test->execute_ok('scpers_null1');

$test->state_is('SUCCESS'); 
$test->disconnect();


open(CERT, ">$cfg{instance}{buffer}");
print CERT $ser->serialize( \@certs ); 
close CERT; 

  

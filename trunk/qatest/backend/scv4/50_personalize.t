#!/usr/bin/perl
#

# You need to remove the recorded puk for the card from the 
# datapool before running the script, or you get an error in Test #3
# The scripts needs a dummy csr to post - this is created on the first 
# run at "sctest.csr" by calling openssl.

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


my $serializer = OpenXPKI::Serialization::Simple->new();

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
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";

my $ser = OpenXPKI::Serialization::Simple->new();

my %wfparam = (        
        user_id => 'oliver.welter@example.com',
        token_id => 'gem2_12345678',
        chip_id => 'chipid1234',
        certs_on_card => '',
        login_id => 'oliwel',
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

$test->state_is('POLICY_INPUT_REQUIRED');
$test->param_is('policy_input_required','login_ids', 'Check what to do');
$test->param_is('policy_max_login_ids','1', 'Read Policy Setting (max_login_ids)');

my $login = shift @{ $ser->deserialize($test->param('policy_login_ids'))};

$test->execute_ok('scpers_apply_csr_policy', { 'login_ids' => $ser->serialize( [ $login ] ) });

# CSR done - Installs
$test->state_is('PKCS12_TO_INSTALL');
$test->execute_ok('scpers_refetch_p12');

#$test->param_isnt('_keypassword','', 'Check for keypassword');
#$test->param_isnt('_password','', 'Check for password');
$test->param_isnt('_pkcs12base64','', 'Check for P12'); 

open PKCS10, ">sctest.p12";
print PKCS10 $test->param('_pkcs12base64');
close PKCS10;

$test->execute_ok('scpers_cert_inst_ok');


$test->state_is('CERT_TO_INSTALL');
$test->param_is('cert_install_type','x509', 'Check for x509 type parameter');
$test->param_like('certificate','/-----BEGIN CERTIFICATE.*/','Check for PEM certificate');            
$test->execute_ok('scpers_cert_inst_ok');

$test->state_is('HAVE_CERT_TO_PUBLISH');

#$test->state_is('SUCCESS'); 
$test->disconnect();

  
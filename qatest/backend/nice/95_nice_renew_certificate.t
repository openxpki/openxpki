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

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

use OpenXPKI::Test::More;
use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '9x_nice.cfg', \%cfg, @cfgpath );

my $test = OpenXPKI::Test::More->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";


my $buffer = do { # slurp
	local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<', $cfg{instance}{buffer};
    <$HANDLE>;
};

my $serializer = OpenXPKI::Serialization::Simple->new();
my $input_data = $serializer->deserialize( $buffer );

my $cert_identifier = $input_data->{'cert_identifier'};

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 10 );

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";

my %cert_info = (
	requestor_gname => "Robert",
	requestor_name => "Renew",
);
 
my %wfparam = (	
	org_cert_identifier => $cert_identifier,
	csr_type => 'pkcs10'
);

print "Renewal: $cert_identifier\n";
	
$test->create_ok( 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_RENEWAL_REQUEST' , \%wfparam, 'Create Renewal Test Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('SERVER_KEY_GENERATION');

# Trigger key generation
my $param_serializer = OpenXPKI::Serialization::Simple->new({SEPARATOR => "-"});

$test->execute_ok( 'I18N_OPENXPKI_WF_ACTION_GENERATE_KEY', {
	_key_type => "RSA",
    _key_gen_params => $param_serializer->serialize( { KEY_LENGTH => 2048, ENC_ALG => "aes128" } ),
    _password => "m4#bDf7m3abd" } ) or die "Error - keygen failed: $@";
 	

$test->state_is('PENDING');


$test->disconnect();
 
# Re-login with Operator for approval
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{role},
) or die "Error - connect failed: $@";


$test->execute_ok( 'I18N_OPENXPKI_WF_ACTION_APPROVE_CSR' );

$test->state_is('APPROVAL');

$test->execute_ok( 'I18N_OPENXPKI_WF_ACTION_PERSIST_CSR' );

#$test->param_like( 'cert_subject', "/^CN=$sSubject,.*/" , 'Certificate Subject');

$test->state_is('SUCCESS');

open(CERT, ">$cfg{instance}{buffer}");
print CERT $serializer->serialize({ cert_identifier => $test->param( 'cert_identifier' ) }); 
close CERT; 


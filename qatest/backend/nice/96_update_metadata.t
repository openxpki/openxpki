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
use OpenXPKI::Serialization::Simple;

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

$test->set_verbose($cfg{instance}{verbose});

$test->plan( tests => 12 );
 
my $buffer = do { # slurp
	local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<', $cfg{instance}{buffer};
    <$HANDLE>;
};

my $serializer = OpenXPKI::Serialization::Simple->new();
my $input_data = $serializer->deserialize( $buffer );

my $cert_identifier = $input_data->{'cert_identifier'};

$test->like( $cert_identifier , "/^[0-9a-zA-Z-_]{27}/", 'Certificate Identifier')
 || die "Unable to proceed without Certificate Identifier: $@";
 

# Login to use socket
$test->connect_ok(
    user => $cfg{operator}{name},
    password => $cfg{operator}{role},
) or die "Error - connect failed: $@";

# First try an autoapproval request

my %wfparam = (
	cert_identifier => $cert_identifier,	    
);
    
$test->create_ok( 'I18N_OPENXPKI_WF_TYPE_CHANGE_METADATA' , \%wfparam, 'Create Workflow')
 or die "Workflow Create failed: $@";

$test->state_is('DATA_LOADED');

$test->diag('Current data ' . Dumper $test->param( 'current_metadata') );

$test->execute_ok( 'changemeta_update_context', { metadata_update => $serializer->serialize({ 
    'requestor' => 'Uli Update',
    'certowner' => 'Andreas Anders'    
})} );

$test->state_is('DATA_LOADED');

$test->execute_ok( 'changemeta_persist' );

$test->state_is('SUCCESS');

$test->disconnect();
 

use strict;
use warnings;
use Carp;
use English;
use Test::More qw(no_plan);

#plan tests => 8;

use OpenXPKI::Tests;
use OpenXPKI::Client;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

diag("Test workflow tools\n");
our $debug = 0;

my $realm = 'User TEST CA';
$realm = undef;

# reuse the already deployed server
#my $instancedir = 't/60_workflow/test_instance';
my $instancedir = '';
my $socketfile  = $instancedir . '/var/openxpki/openxpki.socket';
my $pidfile     = $instancedir . '/var/openxpki/openxpki.pid';

my $tok_id;
my $wf_type = 'I18N_OPENXPKI_WF_TYPE_TEST_WFTOOLS';
my ( $msg, $wf_id, $client );

my $test_user = 'user002@localhost';
my $test_role = 'User';

BEGIN { use_ok('OpenXPKI::Server::Workflow::WFObject'); }

############################################################
# START TESTS
############################################################

diag('##################################################');
diag('# Init tests');
diag('##################################################');

TODO: {
    local $TODO = 'need to find path of PID file';
    ok( -e $pidfile, "PID file exists" );
}

ok( -e $socketfile, "Socketfile exists" );

# Note: if anything in this section fails, just die immediately
# because continuing with the other tests then makes no sense.

$client = wfconnect_ok( 
    { user => $test_user,
        role => $test_role,
        socketfile => $socketfile,
        realm => $realm
    })
or die "login failed";

$wf_id = wfcreate_ok( $client, $wf_type, {} ) or die "Error creating workflow: $@";

wfstate_is( $client, $wf_id, 'INITIALIZED' ) 
    or die( "State after create must be INITIALIZED: ", Dumper($msg) );

############################################################
# We now have an active workflow at INITIALIZED. Now, run
# some tests
############################################################

diag('##################################################');
diag('# Run WFArray Tests');
diag('##################################################');

wfexec_ok( $client, $wf_id, 'test_wfarray', {}) or die "Error executing test_wfarray: $@";
wfstate_is( $client, $wf_id, 'TEST_WFARRAY');

# array is empty

wfexec_ok( $client, $wf_id, 'wfarray_push', { wfarray_val => 'Apples' } );

# array contains [ 'Apples' ];

wfexec_ok( $client, $wf_id, 'wfarray_push', { wfarray_val => 'Oranges' } );

# array contains [ 'Apples', 'Oranges' ];

wfexec_ok( $client, $wf_id, 'wfarray_count', {} );

wfparam_is( $client, $wf_id, 'wfarray_val', '2',
    'Count of array should be 2' );

wfexec_ok( $client, $wf_id, 'wfarray_pop', {} );

# array contains [ 'Apples' ];

wfparam_is( $client, $wf_id, 'wfarray_val', 'Oranges',
    'Last entry should be Oranges' );

wfexec_ok( $client, $wf_id, 'wfarray_count', {} );

wfparam_is( $client, $wf_id, 'wfarray_val', '1',
    'Count of array should be 1' );

wfexec_ok( $client, $wf_id, 'wfarray_unshift', { wfarray_val => 'Lemons' } );

# array contains [ 'Lemons', 'Apples' ];

wfexec_ok( $client, $wf_id, 'wfarray_count', {} );

wfparam_is( $client, $wf_id, 'wfarray_val', '2',
    'Count of array should be 2' );

wfexec_ok( $client, $wf_id, 'wfarray_unshift',
    { wfarray_val => 'Cherries' } );

# array contains [ 'Cherries', 'Lemons', 'Apples' ];

wfexec_ok( $client, $wf_id, 'wfarray_count', {} );

wfparam_is( $client, $wf_id, 'wfarray_val', '3',
    'Count of array should be 3' );

wfexec_ok( $client, $wf_id, 'wfarray_shift', {} );

# array contains [ 'Lemons', 'Apples' ];

wfparam_is( $client, $wf_id, 'wfarray_val', 'Cherries',
    'Last entry should be Cherries' );

wfexec_ok( $client, $wf_id, 'wfarray_count', {} );

wfparam_is( $client, $wf_id, 'wfarray_val', '2',
    'Count of array should be 2' );

wfexec_ok( $client, $wf_id, 'wfarray_value', { wfarray_index => '1' } );

wfparam_is( $client, $wf_id, 'wfarray_val', 'Apples',
    'Should find Apples at index 1' );

# Done with WFArray tests
wfexec_ok( $client, $wf_id, 'subtests_done', {} );
wfstate_is( $client, $wf_id, 'INITIALIZED' ) 
    or die( "State after test set must be INITIALIZED: ", Dumper($msg) );

############################################################
# Finish the active workflow
############################################################

wfexec_ok( $client, $wf_id, 'tests_done', {} );

wfstate_is( $client, $wf_id, 'SUCCESS' );

#is( $msg->{PARAMS}->{WORKFLOW}->{STATE},
#    'SUCCESS', 'Workflow wfarray_done OK' )
#    or
#    die( "State after wfarray_done must be SUCCESS: ", Dumper($msg) );

# Logout to be able to re-login as the auth users
wfdisconnect();

__END__



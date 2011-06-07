#!/usr/bin/perl
#
# 045_activity_tools.t
#
# Tests misc workflow tools like WFObject, etc.
#
# Note: these tests are non-destructive. They create their own instance
# of the tools workflow, which is exclusively for such test purposes.

use strict;
use warnings;

use lib qw(     /usr/local/lib/perl5/site_perl/5.8.8/x86_64-linux-thread-multi
  /usr/local/lib/perl5/site_perl/5.8.8
  /usr/local/lib/perl5/site_perl
  ../../lib
);

use Carp;
use English;
use Data::Dumper;
use Config::Std;
use File::Basename;

use TestCfg;

my $dirname = dirname($0);

our @cfgpath = ( $dirname . '/../../../config/tests/backend/workflow', $dirname );
our %cfg = ();

my $testcfg = new TestCfg;
$testcfg->read_config_path( '45_activity_tools.cfg', \%cfg, @cfgpath );

package OpenXPKI::Tests::More::Workflow::ActivityTools;
{
    use base qw( OpenXPKI::Tests::More );
    sub wftype { return qw( I18N_OPENXPKI_WF_TYPE_TEST_WFTOOLS ) };

    my ( $msg, $wf_id, $client );

    ###################################################
    # These routines represent individual tasks
    # done by a user. If there is an error in a single
    # step, undef is returned. The reason is in $@ and
    # on success, $@ contains Dumper($msg) if $msg is
    # not normally returned.
    #
    # Each routine takes care of login and logout.
    ###################################################

}

package main;

my $test = OpenXPKI::Tests::More::Workflow::ActivityTools->new(
    {
        socketfile => $cfg{instance}{socketfile},
        realm => $cfg{instance}{realm},
    }
) or die "Error creating new test instance: $@";

$test->plan( tests => 31 );

my $test_user = $cfg{user}{name};
my $test_role = $cfg{user}{role};

$test->connect_ok(
    user => $cfg{user}{name},
    password => $cfg{user}{role},
) or die "Error - connect failed: $@";

$test->create_ok(
    $test->wftype, { }, "Create test workflow" )
    or die "Error creating workflow instance: " . $@;

$test->state_is( 'INITIALIZED' ) 
    or die "State after create must be INITIALIZED";

############################################################
# We now have an active workflow at INITIALIZED. Now, run
# some tests
############################################################

$test->execute_ok(
    'wftest_test_wfarray', {}
)
    or die "Error executing wftest_test_wfarray: $@";

$test->state_is( 'TEST_WFARRAY' );

# array is now empty

$test->execute_ok( 'wftest_wfarray_push', { wfarray_val => 'Apples' } );

# array contains [ 'Apples' ]

$test->execute_ok( 'wftest_wfarray_push', { wfarray_val => 'Oranges' } );

# array contains [ 'Apples', 'Oranges' ];

$test->execute_ok( 'wftest_wfarray_count', {} );

$test->param_is( 'wfarray_val', '2',
    'Count of array should be 2' );

$test->execute_ok( 'wftest_wfarray_pop', {} );

# array contains [ 'Apples' ];

$test->param_is( 'wfarray_val', 'Oranges',
    'Last entry should be Oranges' );

$test->execute_ok( 'wftest_wfarray_count', {} );

$test->param_is( 'wfarray_val', '1',
    'Count of array should be 1' );

$test->execute_ok( 'wftest_wfarray_unshift', { wfarray_val => 'Lemons' } );

# array contains [ 'Lemons', 'Apples' ];

$test->execute_ok( 'wftest_wfarray_count', {} );

$test->param_is( 'wfarray_val', '2',
    'Count of array should be 2' );

$test->execute_ok( 'wftest_wfarray_unshift',
    { wfarray_val => 'Cherries' } );

# array contains [ 'Cherries', 'Lemons', 'Apples' ];

$test->execute_ok( 'wftest_wfarray_count', {} );

$test->param_is( 'wfarray_val', '3',
    'Count of array should be 3' );

$test->execute_ok( 'wftest_wfarray_shift', {} );

# array contains [ 'Lemons', 'Apples' ];

$test->param_is( 'wfarray_val', 'Cherries',
    'Last entry should be Cherries' );

$test->execute_ok( 'wftest_wfarray_count', {} );

$test->param_is( 'wfarray_val', '2',
    'Count of array should be 2' );

$test->execute_ok( 'wftest_wfarray_value', { wfarray_index => '1' } );

$test->param_is( 'wfarray_val', 'Apples',
    'Should find Apples at index 1' );

# Try fetching WFArray object instance

my $wfobj = $test->array('wfarray_test');
$test->is( $wfobj->count(), 2, 'direct WFArray: length of array');
$test->is( $wfobj->value( 1 ), 'Apples', 'direct WFArray: contents of last element');

# Done with WFArray tests
$test->execute_ok( 'wftest_subtests_done', {} );
$test->state_is( 'INITIALIZED' ) 
    or die( "State after test set must be INITIALIZED: " );

############################################################
# Finish the active workflow
############################################################

$test->execute_ok( 'wftest_tests_done', {} );

$test->state_is( 'SUCCESS' );

#is( $msg->{PARAMS}->{WORKFLOW}->{STATE},
#    'SUCCESS', 'Workflow wfarray_done OK' )
#    or
#    die( "State after wfarray_done must be SUCCESS: ", Dumper($msg) );

# Logout to be able to re-login as the auth users
$test->disconnect();


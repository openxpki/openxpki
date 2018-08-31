#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Data::UUID;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

plan tests => 3;

#
# Setup test context
#
my $workflow_def = {
    'head' => {
        'label' => 'wf_that_explodes',
        'persister' => 'OpenXPKI',
        'prefix' => 'wfthatexplodes',
    },
    'state' => {
        'INITIAL' => {
            'action' => [ 'noop > EXPLODING' ],
        },
        'EXPLODING' => {
            'action' => [ 'throw_exception > SUCCESS' ],
        },
        'SUCCESS' => {
            'label' => 'Done',
            'description' => 'We are finished',
        },
        'FAILURE' => {
            'label' => 'Workflow has failed',
            'description' => 'We are sorry',
        },
    },
    'action' => {
        'noop' => {
            'class' => 'OpenXPKI::Server::Workflow::Activity::Noop',
        },
        'throw_exception' => {
            'class' => 'TestWorkflowActivityWithException',
        },
    },
    'acl' => {
        'User' => { creator => 'any', techlog => 1, history => 1 },
    },
};

my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms Workflows ) ],
    add_config => {
        "realm.alpha.workflow.def.wf_that_explodes" => $workflow_def,
    },
    #log_level => "debug",
);

#
# synchronous
#
CTX('session')->data->pki_realm('alpha');
CTX('session')->data->role('User');
CTX('session')->data->user('wilhelm');


package TestWorkflowResume;
package main;

$TestWorkflowResume::trigger_exception = 1; # this will be used in TestWorkflowActivityWithException to trigger the exception
my $wf = $oxitest->create_workflow("wf_that_explodes");

my $result = $oxitest->api2_command("execute_workflow_activity" => {
    id => $wf->id,
    activity => "wfthatexplodes_throw_exception",
    async => 1,
    wait => 1,
});

is $result->{workflow}->{proc_state}, "exception", "workflow is in EXCEPTION state";

$TestWorkflowResume::trigger_exception = 0; # this will be used in TestWorkflowActivityWithException to trigger the exception
my $info = $oxitest->api2_command("resume_workflow" => { id => $wf->id, async => 1, wait => 1 });

is $info->{workflow}->{proc_state}, "finished", "workflow is finished";
is $info->{workflow}->{state}, "SUCCESS", "workflow is in state SUCCESS";

# delete test workflows
$oxitest->dbi->start_txn;
$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => "wf_that_explodes" } );
$oxitest->dbi->commit;

1;

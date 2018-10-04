#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;

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

my $result = $oxitest->api_command("execute_workflow_activity" => {
    ID => $wf->id,
    ACTIVITY => "wfthatexplodes_throw_exception",
    ASYNC => "watch",
});

is $result->{WORKFLOW}->{PROC_STATE}, "exception", "workflow is in EXCEPTION state";

$TestWorkflowResume::trigger_exception = 0; # this will be used in TestWorkflowActivityWithException to trigger the exception
my $info = $oxitest->api_command("resume_workflow" => { ID => $wf->id, ASYNC => "watch" });

is $info->{WORKFLOW}->{PROC_STATE}, "finished", "workflow is finished";
is $info->{WORKFLOW}->{STATE}, "SUCCESS", "workflow is in state SUCCESS";

1;

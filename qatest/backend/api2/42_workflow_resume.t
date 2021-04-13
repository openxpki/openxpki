#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;

use Test::Exception;
use Data::UUID;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
#use OpenXPKI::Debug; BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server.*'} = 4; $OpenXPKI::Debug::LEVEL{'.*Workflow.*'} = 8 }
use OpenXPKI::Test;

plan tests => 2;

#
# Setup test context
#
my $workflow_def1 = {
    'head' => {
        'label' => 'wf_that_explodes1',
        'persister' => 'OpenXPKI',
        'prefix' => 'wfthatexplodes1',
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
        'User' => { creator => 'any', techlog => 1, history => 1, resume => 1 },
    },
};

my $workflow_def2 = {
    'head' => {
        'label' => 'wf_that_explodes2',
        'persister' => 'OpenXPKI',
        'prefix' => 'wfthatexplodes2',
    },
    'state' => {
        'INITIAL' => {
            'action' => [ 'boom > SUCCESS' ],
        },
        'SUCCESS' => {
            'label' => 'Done',
            'description' => 'We are finished',
        },
    },
    'action' => {
        'boom' => {
            'class' => 'TestWorkflowActivityWithException',
        },
    },
    'acl' => {
        'User' => { creator => 'any', techlog => 1, history => 1, resume => 1 },
    },
};

my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms Workflows ) ],
    add_config => {
        "realm.alpha.workflow.def.wf_that_explodes1_$uuid" => $workflow_def1,
        "realm.alpha.workflow.def.wf_that_explodes2_$uuid" => $workflow_def2,
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

#
# Test A: crash on some action
#
subtest "workflow crashing on some action" => sub {
    plan tests => 6;

    $TestWorkflowResume::trigger_exception = 1; # this will be used in TestWorkflowActivityWithException to trigger the exception
    my $wf;
    lives_ok {
        $wf = $oxitest->create_workflow("wf_that_explodes1_$uuid");
    } "workflow is created";

    my $result;
    lives_ok {
        $result = $oxitest->api2_command("execute_workflow_activity" => {
            id => $wf->id,
            activity => "wfthatexplodes1_throw_exception",
            # async and wait prevent the API call from throwing an exception
            async => 1,
            wait => 1,
        });
    } "workflow activity is executed (and crashes in the background)";

    is $result->{workflow}->{proc_state}, "exception", "workflow is in EXCEPTION state";

    $TestWorkflowResume::trigger_exception = 0; # this will be used in TestWorkflowActivityWithException to trigger the exception
    my $info;
    lives_ok {
        $info = $oxitest->api2_command("resume_workflow" => { id => $wf->id, async => 1, wait => 1 });
    } "resume workflow";

    is $info->{workflow}->{proc_state}, "finished", "workflow is finished";
    is $info->{workflow}->{state}, "SUCCESS", "workflow is in state SUCCESS";
};

#
# Test B: crash on INITIAL action
#
subtest "workflow crashing on INITIAL action" => sub {
    plan tests => 5;

    $TestWorkflowResume::trigger_exception = 1; # this will be used in TestWorkflowActivityWithException to trigger the exception

    my $wf;
    lives_and {
        $wf = $oxitest->create_workflow("wf_that_explodes2_$uuid");
        like $wf->id, qr/^\d+$/;
    } "create_workflow() returns after crash in INITIAL action";

    lives_and {
        my $info = $oxitest->api2_command("get_workflow_info" => { id => $wf->id });
        is $info->{workflow}->{proc_state}, "exception", "workflow is in EXCEPTION state";
    } "workflow was persisted";

    $TestWorkflowResume::trigger_exception = 0; # this will be used in TestWorkflowActivityWithException to trigger the exception
    my $info;
    lives_ok {
        $info = $oxitest->api2_command("resume_workflow" => { id => $wf->id, async => 1, wait => 1 });
    } "resume workflow";

    is $info->{workflow}->{proc_state}, "finished", "workflow is finished";
    is $info->{workflow}->{state}, "SUCCESS", "workflow is in state SUCCESS";
};

# delete test workflows
$oxitest->dbi->start_txn;
$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => [ -like => "%$uuid" ] } );
$oxitest->dbi->commit;

# delete test workflows
$oxitest->dbi->start_txn;
$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => "wf_that_explodes" } );
$oxitest->dbi->commit;

1;

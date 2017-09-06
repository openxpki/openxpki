#!/usr/bin/perl
#
# Test if a background workflow (i.e. forking) works in conjunction with a
# workflow action that calls Proc::SafeExec.
# Previously, there have been problems with SIGCHLD, see Github issue #517.
#
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;

# Project modules
use lib "$Bin/lib";
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Test::CertHelper::Database;

plan tests => 4;

#
# Setup test context
#
sub workflow_def {
    my ($name) = @_;
    return {
        'head' => {
            'label' => $name,
            'persister' => 'OpenXPKI',
            'prefix' => $name,
        },
        'state' => {
            'INITIAL' => {
                'action' => [ 'initialize > BACKGROUNDING' ],
            },
            'BACKGROUNDING' => {
                'autorun' => 1,
                'action' => [ 'pause_before_fork > LOITERING' ],
            },
            'LOITERING' => {
                'autorun' => 1,
                'action' => [ 'do_something > SUCCESS' ],
            },
            'SUCCESS' => {
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_DESCRIPTION',
                'output' => [ 'message', 'link', 'role' ],
            },
            'FAILURE' => {
                'label' => 'Workflow has failed',
            },
        },
        'action' => {
            'initialize' => {
                'class' => 'OpenXPKI::Server::Workflow::Activity::Noop',
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_MOTD_INITIALIZE_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_MOTD_INITIALIZE_DESCRIPTION',
            },
            'do_something' => {
                'class' => 'OpenXPKI::Test::Is13Prime',
            },
            'pause_before_fork' => {
                'class' => 'OpenXPKI::Server::Workflow::Activity::Tools::Disconnect',
                'param' => { 'pause_info' => 'We want this to be picked up by the watchdog' },
            },
        },
        'field' => {},
        'validator' => {},
        'acl' => {
            'User' => { creator => 'any', techlog => 1, history => 1 },
        },
    };
};

sub test_wf_instance {
    my ($pki_realm, $name) = @_;
    CTX('session')->data->pki_realm($pki_realm);
    my $wfinfo = CTX('api')->create_workflow_instance({
        WORKFLOW => $name,
        PARAMS => {},
    });

    die($wfinfo->{LIST}->[0]->{LABEL} || 'Unknown error occured during workflow creation')
        if $wfinfo and exists $wfinfo->{SERVICE_MSG} and $wfinfo->{SERVICE_MSG} eq 'ERROR';

    return $wfinfo->{WORKFLOW};
}

my $oxitest = OpenXPKI::Test->new;
$oxitest->workflow_config("alpha", "wf_type_1", workflow_def("wf_type_1"));
$oxitest->setup_env->init_server('workflow_factory', 'crypto_layer');

CTX('session')->data->role('User');
CTX('session')->data->user('wilhelm');
my $wf_t1_a = test_wf_instance "alpha", "wf_type_1";

CTX('session')->data->pki_realm('alpha');

#diag explain OpenXPKI::Workflow::Config->new->workflow_config;

#
# wakeup_workflow
#
lives_and {
    my $result = CTX('api')->wakeup_workflow({
        ID => $wf_t1_a->{ID},
        ASYNC => 'fork',
    });
    # ... this will automatically call "add_link" and "set_motd"
    is $result->{WORKFLOW}->{STATE}, 'BACKGROUNDING';
} "wakeup_workflow() - wakeup workflow and run in backround (fork)";

# Wait for backgrounded (forked) workflow to finish
my $result;
while (1) {
    my $result = CTX('api')->search_workflow_instances({ SERIAL => [ $wf_t1_a->{ID} ] });
    # no workflow found?
    if ($result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'} != $wf_t1_a->{ID}) {
        diag "Workflow with ID ".$wf_t1_a->{ID}." not found!";
        fail "Workflow finished successfully";
        last;
    }
    # wait if paused (i.e. resuming in progress) or still running (the remaining steps)
    if ($result->[0]->{'WORKFLOW.WORKFLOW_PROC_STATE'} =~ /^(running|pause)$/) {
        sleep 1;
        next;
    }
    # compare result
    cmp_deeply $result, [ superhashof({
        'WORKFLOW.WORKFLOW_SERIAL' => $wf_t1_a->{ID},
        'WORKFLOW.WORKFLOW_PROC_STATE' => 'finished', # could be 'exception' if things go wrong
        'WORKFLOW.WORKFLOW_STATE' => 'SUCCESS',
    }) ], "Workflow finished successfully" or diag explain $result;
    last;
}

lives_and {
    my $result = CTX('api')->get_workflow_info({ ID => $wf_t1_a->{ID} });
    cmp_deeply $result->{WORKFLOW}->{CONTEXT}->{is_13_prime}, 1;
} "Workflow action returns correct result";

#
# get_workflow_history
#
lives_and {
    my $result = CTX('api')->get_workflow_history({ ID => $wf_t1_a->{ID} });
    cmp_deeply $result, [
        superhashof({ WORKFLOW_STATE => "INITIAL", WORKFLOW_ACTION => re(qr/create/i) }),
        superhashof({ WORKFLOW_STATE => "INITIAL", WORKFLOW_ACTION => re(qr/initialize/i) }),
        superhashof({ WORKFLOW_STATE => "BACKGROUNDING", WORKFLOW_ACTION => re(qr/pause_before_fork/i) }), # pause
        superhashof({ WORKFLOW_STATE => "BACKGROUNDING", WORKFLOW_ACTION => re(qr/pause_before_fork/i) }), # wakeup
        superhashof({ WORKFLOW_STATE => "BACKGROUNDING", WORKFLOW_ACTION => re(qr/pause_before_fork/i) }), # state change
        superhashof({ WORKFLOW_STATE => "LOITERING", WORKFLOW_ACTION => re(qr/do_something/i) }),
    ] or diag explain $result;
} "get_workflow_history()";

1;

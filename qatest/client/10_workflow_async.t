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
use lib "$Bin/lib", "$Bin/../lib", "$Bin/../../core/server/t/lib";
use OpenXPKI::Test;


# plan tests => 14; WE CANNOT PLAN tests as there is a while loop that sends commands (which are tests)


#
# Setup test context
#
sub workflow_def {
    my ($name) = @_;
    (my $cleanname = $name) =~ s/[^0-9a-z]//gi;
    return {
        'head' => {
            'label' => $name,
            'persister' => 'OpenXPKI',
            'prefix' => $cleanname,
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
            'pause_before_fork' => {
                'class' => 'OpenXPKI::Server::Workflow::Activity::Tools::Disconnect',
                'param' => { 'pause_info' => 'We want this to be picked up by the watchdog' },
            },
            'do_something' => {
                'class' => 'OpenXPKI::Test::Is13Prime',
            },
        },
        'field' => {},
        'validator' => {},
        'acl' => {
            'CA Operator' => { creator => 'any', techlog => 1, history => 1 },
        },
    };
};

my $oxitest = OpenXPKI::Test->new(
    with => [ "SampleConfig", "Server", "Workflows" ],
    also_init => "crypto_layer",
    start_watchdog => 1,
    add_config => {
        "realm.democa.workflow.def.wf_type_1" => workflow_def("wf_type_1"),
    },
);

my $client = $oxitest->new_client_tester;
$client->login("democa" => "caop");

sub wait_for_proc_state {
    my ($wfid, $state_regex) = @_;

    my $result;
    my $count = 0;
    while ($count++ < 20) {
        $result = $client->send_command_ok("search_workflow_instances" => { id => [ $wfid ] });
        # no workflow found?
        if (not scalar @$result or $result->[0]->{'workflow_id'} != $wfid) {
            die("Workflow with ID $wfid not found");
        }
        # wait if paused (i.e. resuming in progress) or still running (the remaining steps)
        if (not $result->[0]->{'workflow_proc_state'} =~ $state_regex) {
            sleep 1;
            next;
        }
        # expected proc state reached
        return 1;
    }
    die("Timeout reached while waiting for workflow to reach state $state_regex");
}

my $result;

lives_and {
    $result = $client->send_command_ok("create_workflow_instance" => {
        workflow => "wf_type_1",
    });
} "create_workflow_instance()";

my $wf = $result->{workflow} or die('Workflow data not found');
my $wf_id = $wf->{id} or die('Workflow ID not found');

##diag explain OpenXPKI::Workflow::Config->new->workflow_config;

#
# wait for wakeup by watchdog
#
note "waiting for backgrounded (forked) workflow to finish";
wait_for_proc_state $wf_id, qr/^(finished|exception)$/;

#
# get_workflow_info - check action results
#
lives_and {
    $result = $client->send_command_ok("get_workflow_info" => { id => $wf_id });
    cmp_deeply $result->{workflow}, superhashof( {
        'proc_state' => 'finished', # could be 'exception' if things go wrong
        'state' => 'SUCCESS',
        'context' => superhashof( { 'is_13_prime' => 1 } ),
    } );
} "Workflow finished successfully and with correct action result";

#
# get_workflow_history - check correct execution history
#
lives_and {
    $result = $client->send_command_ok("get_workflow_history" => { id => $wf_id });
    cmp_deeply $result, [
        superhashof({ workflow_state => "INITIAL", workflow_action => re(qr/initialize/i), workflow_description => re(qr/^EXECUTE/) }),
        superhashof({ workflow_state => "BACKGROUNDING", workflow_action => re(qr/pause_before_fork/i), workflow_description => re(qr/^PAUSED/) }), # pause
        superhashof({ workflow_state => "BACKGROUNDING", workflow_action => re(qr/pause_before_fork/i), workflow_description => re(qr/^WAKEUP/) }), # wakeup
        superhashof({ workflow_state => "BACKGROUNDING", workflow_action => re(qr/pause_before_fork/i), workflow_description => re(qr/^EXECUTE/) }), # state change
        superhashof({ workflow_state => "LOITERING", workflow_action => re(qr/do_something/i), workflow_description => re(qr/^AUTORUN/) }),
    ] or diag explain $result;
} "get_workflow_history()";

$oxitest->stop_server;

done_testing;

1;

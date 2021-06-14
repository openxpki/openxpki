#!/usr/bin/env perl
#
# Tests if the watchdog correctly picks up and processes a workflow marked for
# archiving.
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
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;


# plan tests => 14; WE CANNOT PLAN tests as there is a while loop that sends commands (which are tests)


my $workflow_type = "TESTWORKFLOW".int(rand(2**32));

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Server Workflows ) ],
    start_watchdog => 1,
    add_config => {
        "realm.democa.workflow.persister.Archiver" => "
            class: OpenXPKI::Server::Workflow::Persister::Archiver
        ",

        "realm.democa.workflow.def.$workflow_type" => "
            head:
                prefix: testwf
                persister: Archiver
                archive_at: +000000000003

            state:
                INITIAL:
                    action: step1 > SUCCESS

                SUCCESS:

            action:
                step1:
                    class: OpenXPKI::Server::Workflow::Activity::Noop

            acl:
                MyFairyKing:
                    creator: any
                    history: 1
        ",
    },
);

$oxitest->session->data->role("MyFairyKing");

my $result;
my $start_epoch = time();

# create workflow (auto-executes 'step1')
lives_and {
    $result = CTX('api2')->create_workflow_instance(workflow => $workflow_type);
    ok ref $result;
} "create test workflow" or BAIL_OUT "Could not create workflow";

my $wf_info = $result->{workflow};
my $wf_id = $wf_info->{id} or BAIL_OUT('Workflow ID not found');

# get_workflow_info - check 'archive_at'
lives_and {
    $result = CTX('api2')->get_workflow_info(id => $wf_id);
    cmp_deeply $result->{workflow}, superhashof( {
        'proc_state' => 'finished', # could be 'exception' if things go wrong
        'state' => 'SUCCESS',
        'archive_at' => code(sub{ shift > $start_epoch }),
    } );
} "'archive_at' correctly set" or diag explain $result;

# get_workflow_history - history present before archiving
lives_and {
    $result = CTX('api2')->get_workflow_history(id => $wf_id);
    cmp_deeply $result, [
        superhashof({ workflow_state => "INITIAL", workflow_action => re(qr/testwf_step1/i), workflow_description => re(qr/^EXECUTE/) }),
    ] or diag explain $result;
} "get_workflow_history() - history entries created";


note "waiting for watchdog to archive workflow...";
$oxitest->wait_for_proc_state($wf_id, qr/^(archived)$/);


# get_workflow_history - history purging
lives_and {
    $result = CTX('api2')->get_workflow_history(id => $wf_id);
    cmp_deeply $result, [
        superhashof({ workflow_state => "SUCCESS", workflow_description => re(qr/^ARCHIVE/) }),
    ] or diag explain $result;
} "get_workflow_history() - history purged when archiving workflow";

$oxitest->stop_server;

$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $workflow_type });
$oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => $wf_id });

done_testing;

1;

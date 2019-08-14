#!/usr/bin/perl

use strict;
use warnings;
use utf8;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;
use Log::Log4perl qw(:easy);
use Try::Tiny;

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

plan tests => 4;


my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs

#
# Init helpers
#

# Import test certificates
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( SampleConfig Workflows WorkflowCreateCert Server ) ],
    add_config => {
        'realm.democa.workflow.persister.Delayed' => {
            'class' => 'TestWorkflowTimingDelayedPersister',
        },
        "realm.democa.workflow.def.mywf_$uuid" => {
            'head' => {
                'label' => 'mywf',
                'persister' => 'OpenXPKI',
                'prefix' => 'mywf',
                'persister' => 'Delayed',
            },
            'state' => {
                'INITIAL' => {
                    'action' => [ 'noop > INTERMEDIATE' ],
                },
                'INTERMEDIATE' => {
                    'action' => [ 'count > SUCCESS' ],
                },
                'SUCCESS' => {
                    'label' => 'Finished',
                },
            },
            'action' => {
                'noop' => {
                    'class' => 'OpenXPKI::Server::Workflow::Activity::Noop',
                },
                'count' => {
                    'class' => 'TestWorkflowTimingCountAction',
                },
            },
            'acl' => {
                'User' => { creator => 'any', techlog => 1, history => 1 },
            },
        },
    },
);

# set user role to be allowed to create the workflow above
$oxitest->set_user("democa" => "user");

#
# Tests
#

my $wftest;

lives_and {
    $wftest = $oxitest->create_workflow("mywf_$uuid");
    $wftest->state_is('INTERMEDIATE');
} 'Create test workflow' or die "Creating workflow failed";

lives_and {
    is $wftest->metadata->{workflow}->{proc_state}, "manual";
} 'Process state is "manual"';

# set flag that leads to a delay before a new workflow state (like "running")
# is saved (we use TestWorkflowTimingDelayedPersister to do that)
open my $fh, '>', $oxitest->testenv_root . '/TestWorkflowTiming_wait_a_bit';
close $fh;

# Attempt to execute the same workflow action multiple times (asynchronously).
# Two out of three attempts should throw an exception.
for (1..3) {
    try {
        $oxitest->api2_command(
            execute_workflow_activity => {
                id => $wftest->id,
                activity => "mywf_count",
                async => 1,
            }
        );
    }
    catch {
        note $_;
    };
};

# wait for the delayed background processes to finish
sleep 3;

$wftest->metadata; # requery workflow state
$wftest->state_is('SUCCESS');

my $content = do {
    local $/;
    open my $fh, "<", $oxitest->testenv_root . '/TestWorkflowTiming_counter' or return;
    <$fh>;
};

is $content, "x", "Workflow action only gets executed once";

unlink $oxitest->testenv_root . '/TestWorkflowTiming_wait_a_bit'; # should be done by TestWorkflowTimingDelayedPersister, but you never know

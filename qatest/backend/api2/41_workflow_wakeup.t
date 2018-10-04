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
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

plan tests => 6;

#
# Setup test context
#
my $workflow_def = {
    'head' => {
        'label' => 'wf_with_a_rest',
        'persister' => 'OpenXPKI',
        'prefix' => 'wfwitharest',
    },
    'state' => {
        'INITIAL' => {
            'action' => [ 'noop > RESTING' ],
        },
        'RESTING' => {
            'autorun' => 1,
            'action' => [ 'pause > SUCCESS' ],
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
        'pause' => {
            'class' => 'OpenXPKI::Server::Workflow::Activity::Tools::Disconnect',
            'param' => { 'pause_info' => 'Tea time!' },
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
        "realm.alpha.workflow.def.wf_with_a_rest_$uuid" => $workflow_def,
    },
    #log_level => "debug",
);

#
# synchronous
#
CTX('session')->data->pki_realm('alpha');
CTX('session')->data->role('User');
CTX('session')->data->user('wilhelm');
my $wf = $oxitest->create_workflow("wf_with_a_rest_$uuid");
$wf->state_is("RESTING");

my $info = $oxitest->api2_command("wakeup_workflow" => { id => $wf->id, type => "wf_with_a_rest_$uuid" });
is $info->{workflow}->{state}, "SUCCESS", "synchronous wakeup successful";

#
# asynchronous wakeup ('watch'), but watching and waiting
#
$wf = $oxitest->create_workflow("wf_with_a_rest_$uuid");
$wf->state_is("RESTING");

$info = $oxitest->api2_command("wakeup_workflow" => { id => $wf->id, async => 1, wait => 1 });
is $info->{workflow}->{state}, "SUCCESS", "asynchronous wakeup successful (blocking mode)";

#
# asynchronous wakeup ('fork')
#
$wf = $oxitest->create_workflow("wf_with_a_rest_$uuid");
$wf->state_is("RESTING");

$info = $oxitest->api2_command("wakeup_workflow" => { id => $wf->id, async => 1 });

my $timeout = time + 6;
while (time < $timeout) {
    $info = $oxitest->api2_command("get_workflow_info" => { id => $wf->id });
    last if $info->{workflow}->{state} eq "SUCCESS";
    sleep 1;
}
is $info->{workflow}->{state}, "SUCCESS", "asynchronous wakeup successful (nonblocking mode)";

# delete test workflows
$oxitest->dbi->start_txn;
$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => [ -like => "%$uuid" ] } );
$oxitest->dbi->commit;

1;

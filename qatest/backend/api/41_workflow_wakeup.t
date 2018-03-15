#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;

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

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms Workflows ) ],
    add_config => {
        "realm.alpha.workflow.def.wf_with_a_rest" => $workflow_def,
    },
    #log_level => "debug",
);

#
# synchronous
#
CTX('session')->data->pki_realm('alpha');
CTX('session')->data->role('User');
CTX('session')->data->user('wilhelm');
my $wf = $oxitest->create_workflow("wf_with_a_rest");
$wf->state_is("RESTING");

my $info = $oxitest->api_command("wakeup_workflow" => { ID => $wf->id });
is $info->{WORKFLOW}->{STATE}, "SUCCESS", "synchronous wakeup successful";

#
# asynchronous wakeup ('watch'), but watching and waiting
#
$wf = $oxitest->create_workflow("wf_with_a_rest");
$wf->state_is("RESTING");

$info = $oxitest->api_command("wakeup_workflow" => { ID => $wf->id, ASYNC => "watch" });
is $info->{WORKFLOW}->{STATE}, "SUCCESS", "asynchronous wakeup (mode: 'watch') successful";

#
# asynchronous wakeup ('fork')
#
$wf = $oxitest->create_workflow("wf_with_a_rest");
$wf->state_is("RESTING");

$info = $oxitest->api_command("wakeup_workflow" => { ID => $wf->id, ASYNC => "fork" });

my $timeout = time + 6;
while (time < $timeout) {
    $info = CTX('api')->get_workflow_info({ ID => $wf->id });
    last if $info->{WORKFLOW}->{STATE} eq "SUCCESS";
    sleep 1;
}
is $info->{WORKFLOW}->{STATE}, "SUCCESS", "asynchronous wakeup (mode: 'fork') successful";

1;

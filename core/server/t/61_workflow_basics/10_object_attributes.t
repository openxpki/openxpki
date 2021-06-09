#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use Data::UUID;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute.*'} = 100;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;

plan tests => 20;

#
# Setup test context
#
my $workflow_type = "TESTWORKFLOW".int(rand(2**32));
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms ) ],
    also_init => "workflow_factory",
    add_config => {
        "realm.alpha.workflow.def.$workflow_type" => {
            head => { prefix => "testwf", persister => 'OpenXPKI' },
            state => {
                INITIAL => { action => [ 'doit > DONE' ] },
                DONE    => { },
            },
            action => {
                doit => { class => 'OpenXPKI::Server::Workflow::Activity::Noop' },
            },
            acl => { PrincesOfTheUniverse => { creator => 'any' } },
        },
    },
);

$oxitest->session->data->role("PrincesOfTheUniverse");

#
# Tests
#
my $factory = CTX('workflow_factory')->get_factory;
my $workflow;
my $workflow_dup;

# Create workflow
lives_and {
    $workflow = $factory->create_workflow($workflow_type);
    ok ref $workflow;
} "create test workflow" or BAIL_OUT "Could not create workflow";

#
# Check initial values of our custom object attributes
#
my %defaults = (
    proc_state => 'init',
    count_try => 0,
    wakeup_at => undef,
    reap_at => undef,
    session_info => undef,
    persist_context => 0,
    is_startup => 1,
    archive_at => undef,
);

for my $k (keys %defaults) {
    is $workflow->$k, $defaults{$k}, "correct default value of '$k' after creation";
}

$workflow->_save();

lives_and {
    $workflow_dup = $factory->fetch_workflow($workflow_type, $workflow->id);
    ok ref $workflow_dup;
} "refetch workflow from database";

for my $k (keys %defaults) {
    is $workflow->$k, $defaults{$k}, "correct default value of '$k' after fetching from db";
}

#
# Check 'archive_at'
#

my %archive_at_tests = (
    'time period' => '+000000000030',
    'epoch (timestamp)' => time() + 100,
);

for my $input_type (keys %archive_at_tests) {
    subtest "set 'archive_at' via $input_type" => sub {
        $workflow->set_archive_at($archive_at_tests{$input_type});
        $workflow->_save();

        my $archive_at = $workflow->archive_at;

        ok $archive_at > time(), "correctly set";

        lives_and {
            $workflow_dup = $factory->fetch_workflow($workflow_type, $workflow->id);
            ok ref $workflow_dup;
        } "refetch workflow from database";

        is $workflow_dup->archive_at, $archive_at, "correctly persisted";
    }, 3;
}

# Cleanup
$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $workflow_type });
$oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => $workflow->id });

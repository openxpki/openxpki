#!/usr/bin/env perl
#
# Tests if the 'archive_at' config parmeter is correctly processed.
#
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use Data::UUID;
use Try::Tiny;

# use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Persister.*'} = 32;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;

try {
    require OpenXPKI::Server::Workflow::Persister::Archiver;
    plan tests => 8;
}
catch {
    plan skip_all => "persister 'Archiver' no available";
};

sub archive_at_ok($$$) {
    my ($testname, $config, $archive_at) = @_;

    subtest $testname => sub {
        my $workflow_type = "TESTWORKFLOW".int(rand(2**32));

        #
        # Setup test context
        #
        my $oxitest = OpenXPKI::Test->new(
            with => [ qw( TestRealms ) ],
            also_init => "workflow_factory",
            add_config => {
                "realm.alpha.workflow.persister.Archiver" =>
                    "class: OpenXPKI::Server::Workflow::Persister::Archiver\n" .
                    ($config->{persister} // ""),

                "realm.alpha.workflow.def.$workflow_type" => "
                    acl:
                        MyFairyKing:
                            creator: any

                    state:
                        INITIAL:
                            action: step1 > AUTO

                        AUTO:
                            action: noop > SUCCESS
                            autorun: 1

                        SUCCESS:

                    action:
                        noop:
                            class: OpenXPKI::Server::Workflow::Activity::Noop
                ",

                "realm.alpha.workflow.def.$workflow_type.head" =>
                    "prefix: testwf\n" .
                    "persister: Archiver\n" .
                    ($config->{wf_head} // ""),

                "realm.alpha.workflow.def.$workflow_type.state.SUCCESS" =>
                    ($config->{wf_state_success} // ""),

                "realm.alpha.workflow.def.$workflow_type.action.step1" =>
                    ($config->{wf_action_step1} // "class: OpenXPKI::Server::Workflow::Activity::Noop"),

            },
        );

        $oxitest->session->data->role("MyFairyKing");

        my $wf1;

        # Create workflow
        lives_and {
            $wf1 = CTX('workflow_factory')->get_factory->create_workflow($workflow_type);
            ok ref $wf1;
        } "create test workflow" or die("Could not create workflow");

        # Run workflow actions to trigger cleanup
        lives_ok {
            $wf1->execute_action("testwf_step1");
        } "execute workflow action";

        my $wf2;
        lives_and {
            $wf2 = CTX('workflow_factory')->get_factory->fetch_workflow($workflow_type, $wf1->id);
            ok ref $wf2;
        } "refetch workflow from database";

        ok $wf2->archive_at >= $archive_at, "'archive_at' correctly set"
            or diag "test failed: ".$wf2->archive_at." >= $archive_at";

        $oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $workflow_type });
        $oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => $wf1->id });
    };
}

#
# Tests
#

my $epoch = time() + 30;
my %archive_at_tests = (
    'time period' => '+000000000030',
    'epoch (timestamp)' => $epoch,
);

for my $input_type (keys %archive_at_tests) {
    my $archive_at = $archive_at_tests{$input_type};
    # persister config
    archive_at_ok "setting 'archive_at' in persister ($input_type)" =>
        # config
        {
            persister => "archive_at: $archive_at",
        },
        # expected archive_at
        $epoch;

    # workflow head config
    archive_at_ok "setting 'archive_at' in workflow head ($input_type)" =>
        # config
        {
            wf_head => "archive_at: $archive_at",
        },
        # expected archive_at
        $epoch;

    # final workflow state
    archive_at_ok "setting 'archive_at' in final workflow state ($input_type)" =>
        # config
        {
            wf_state_success => "archive_at: $archive_at",
        },
        # expected archive_at
        $epoch;

    archive_at_ok "setting 'archive_at' in persister ($input_type)" =>
        # config
        {
            persister => "archive_at: $archive_at",
            wf_action_step1 =>
                "class: OpenXPKI::Server::Workflow::Activity::Tools::SetArchiveAt\n" .
                "param:\n" .
                "    archive_at: $archive_at\n"
        },
        # expected archive_at
        $epoch;
}
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
use Try::Tiny;

#use OpenXPKI::Debug; $OpenXPKI::Debug::BITMASK{'OpenXPKI::Server::Workflow::Persister.*'} = 16;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;

try {
    require OpenXPKI::Server::Workflow::Persister::Archiver;
    plan tests => 3;
}
catch {
    plan skip_all => "persister 'Archiver' no available";
};

#
# Fail on wrong persister arguments
#
throws_ok {
    my $oxitest = OpenXPKI::Test->new(
        with => [ qw( TestRealms ) ],
        also_init => "workflow_factory",
        add_config => {
            "realm.alpha.workflow.persister.Archiver" => "
                class: OpenXPKI::Server::Workflow::Persister::Archiver
                cleanup_defaults:
                    crash: test dummies
            ",
        },
    );
} qr/defaults must contain/, "Fail on wrong arguments for persister defaults";

sub items_ok($$) {
    my ($config, $items) = @_;

    subtest "check items" => sub {
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
                    head:
                        prefix: testwf
                        persister: Archiver

                    state:
                        INITIAL:
                            action: start_auto > AUTO

                        AUTO:
                            action: set_context set_attr > SUCCESS
                            autorun: 1

                        SUCCESS:

                    action:
                        start_auto:
                            class: OpenXPKI::Server::Workflow::Activity::Noop

                        set_context:
                            class: OpenXPKI::Server::Workflow::Activity::Tools::SetContext
                            param:
                                env: sky
                                temp: -10
                                vehicle: plane

                        set_attr:
                            class: OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute
                            param:
                                shoesize: 10
                                color: blue
                                hairstyle: bald
                    acl:
                        PrincesOfTheUniverse:
                            creator: any
                ",
            },
        );

        $oxitest->session->data->role("PrincesOfTheUniverse");

        my $wf1;

        # Create workflow
        lives_and {
            $wf1 = CTX('workflow_factory')->get_factory->create_workflow($workflow_type);
            ok ref $wf1;
        } "create test workflow" or BAIL_OUT "Could not create workflow";

        # Run workflow actions to trigger cleanup
        lives_ok {
            $wf1->execute_action("testwf_start_auto");
        } "execute workflow action";

        my $wf2;
        lives_and {
            $wf2 = CTX('workflow_factory')->get_factory->fetch_workflow($workflow_type, $wf1->id);
            ok ref $wf2;
        } "refetch workflow from database";

        cmp_deeply $wf2->context->param, {
            %{ $items->{field} },
            creator => ignore(),
            workflow_id => ignore()
        }, "correct context items";

        cmp_deeply $wf2->attrib, $items->{attribute},
            "correct attributes";

        my $history = [ map { $_->action } $wf2->get_history ];
        cmp_bag $history, $items->{history},
            "correct history" or diag explain $history;

        $oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $workflow_type });
        $oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => $wf1->id });
    };
}

#
# Tests
#

# Internal cleanup defaults
items_ok
    # config
    {
        # Internal defaults:
        #   field: finished
        #   attribute: none
        #   history: archived
    },
    # expected results
    {
        field => {},
        attribute => {
            shoesize  => 10,
            color     => 'blue',
            hairstyle => 'bald',
        },
        history => [ qw( testwf_start_auto testwf_set_context testwf_set_attr ) ],
    };

# Explicit persister cleanup settings (merged with internal defaults)
items_ok
    # config
    {
        persister =>
            "cleanup_defaults:\n" .
            "    attribute: finished\n" .
            "    history: finished\n" .
            "",
    },
    # expected results
    {
        field => {},
        attribute => {},
        history => [ qw( ) ],
    };


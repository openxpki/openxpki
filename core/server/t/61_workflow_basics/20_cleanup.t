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

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Persister.*'} = 32;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;

try {
    require OpenXPKI::Server::Workflow::Persister::Archiver;
    plan tests => 5;
}
catch {
    plan skip_all => "persister 'Archiver' no available";
};

my $wf_cleanup = "
    head:
        prefix: testwf
        persister: Archiver

    state:
        INITIAL:
            action: step1 > AUTO

        AUTO:
            action: set_context set_attr > SUCCESS
            autorun: 1

        SUCCESS:
            output:
              - temp

    action:
        step1:
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
                color: blue
                hairstyle: bald
                shoesize: 10

    field:
        env:
            type: text

        temp:
            type: text

        vehicle:
            type: text
            cleanup: none

    attribute:
        shoesize:
            cleanup: none

    acl:
        MyFairyKing:
            creator: any
";

my $wf_onfail = "
    head:
        prefix: testwf
        persister: Archiver

    state:
        INITIAL:
            action: step1 > AUTO

        AUTO:
            action: set_context set_attr > LOITER
            autorun: 1

        LOITER:
            action: step1 > SUCCESS

        SUCCESS:

    action:
        step1:
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
                color: blue
                hairstyle: bald
                shoesize: 10

    field:
        env:
            type: text

        temp:
            type: text

        vehicle:
            type: text
            onfail: keep

    attribute:
        shoesize:
            onfail: keep

    acl:
        MyFairyKing:
            creator: any
";

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
} qr/defaults must contain/, "fail on wrong arguments for persister defaults";

sub items_ok($@) {
    my $testname = shift;
    my %args = @_;
    my $config = $args{config};
    my $items = $args{expected};
    my $test_mode = $args{test_mode};

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

                "realm.alpha.workflow.def.$workflow_type" => ($test_mode eq 'cleanup' ? $wf_cleanup : $wf_onfail),
            },
        );

        $oxitest->session->data->role("MyFairyKing");

        my $wf1;

        # Create workflow
        lives_and {
            $wf1 = CTX('workflow_factory')->get_factory->create_workflow($workflow_type);
            ok ref $wf1;
        } "create test workflow" or die("Could not create workflow");

        # Run workflow action to
        #  - set fields and attributes and
        #  - trigger cleanup (only if $fail == 0)
        lives_ok {
            $wf1->execute_action("testwf_step1");
        } "execute workflow action";

        if ($test_mode eq 'onfail') {
            note "manually failing workflow";
            $wf1->set_failed('entangled something', 'we just saw this...');
        }

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
            "correct history"
                or diag(join "", map { sprintf "[%s] %s --> ", $_->state, $_->action  } sort { $a->date->epoch <=> $b->date->epoch } $wf2->get_history);

        $oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $workflow_type });
        $oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => $wf1->id });
    };
}

#
# Tests
#

# Input for each test:
#
# Fields:
#   env: sky
#   temp: -10           # part of the 'output' of state SUCCESS
#   vehicle: plane      # explicitely configured as "cleanup: none"
#
# Attributes:
#   color: blue
#   hairstyle: bald
#   shoesize: 10        # explicitely configured as "cleanup: none"

# =============================================================================
# Standard cleanup
#
items_ok "standard cleanup: internal defaults",
    test_mode => 'cleanup',
    # config
    config => {
        # Internal defaults:
        #   field: finished
        #   attribute: none
        #   history: archived
    },
    # expected results
    expected => {
        field => {
            vehicle => "plane", # explicitely configured as "cleanup: none"
            temp => -10,        # part of the 'output' of state SUCCESS
        },
        attribute => {
            shoesize  => 10,
            color     => 'blue',
            hairstyle => 'bald',
        },
        history => [ qw( testwf_step1 testwf_set_context testwf_set_attr ) ],
    };

items_ok "standard cleanup: explicit persister settings", # ... merged with internal defaults
    test_mode => 'cleanup',
    # config
    config => {
        persister =>
            "cleanup_defaults:\n" .
            "    attribute: finished\n" .
            "    history: finished\n" .
            "",
    },
    # expected results
    expected => {
        field => {
            vehicle => "plane", # explicitely configured as "cleanup: none"
            temp => -10,        # part of the 'output' of state SUCCESS
        },
        attribute => {
            shoesize => 10,     # explicitely configured as "cleanup: none"
        },
        history => [ qw( ) ],
    };

# =============================================================================
# Cleanup upon forced failure
#
items_ok "forced failure: internal defaults",
    test_mode => 'onfail',
    # config
    config => {
        # Internal defaults:
        #   field: keep
        #   attribute: drop
        #   history: keep
    },
    # expected results
    expected => {
        field => {
            env => 'sky',
            temp => -10,
            vehicle => "plane",
        },
        attribute => {
            shoesize => 10,     # explicitely configured as "onfail: keep"
        },
        # duplicate 'testwf_set_attr' as state FAILURE also logs it as action
        history => [ qw( testwf_step1 testwf_set_context testwf_set_attr testwf_set_attr ) ],
   };

items_ok "forced failure: explicit persister settings",
    test_mode => 'onfail',
    # config
    config => {
        persister =>
            "onfail_defaults:\n" .
            "    field: drop\n" .
            "    history: drop\n" .
            "",
    },
    # expected results
    expected => {
        field => {
            vehicle => "plane", # explicitely configured as "onfail: keep"
        },
        attribute => {
            shoesize => 10,     # explicitely configured as "onfail: keep"
        },
        # state FAILURE also logs 'testwf_set_attr' as action
        history => [ qw( testwf_set_attr ) ],
   };

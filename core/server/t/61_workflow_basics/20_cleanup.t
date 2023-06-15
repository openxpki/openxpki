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
use Feature::Compat::Try;

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
catch ($err) {
    plan skip_all => "persister 'Archiver' no available";
}

my $wf_def = "
head:
    prefix: testwf
    persister: Archiver

state:
    INITIAL:
        action: noop > AUTO

    AUTO:
        action: set_context set_attr > LOITER
        autorun: 1

    LOITER:
        action: noop > SUCCESS

action:
    noop:
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
            creator: dummy
            color: blue
            hairstyle: bald
            shoesize: 10

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
    my $force_failure = $args{force_failure};
    my $fields = $config->{workflow}->{field} // {};
    my $attributes = $config->{workflow}->{attribute} // {};

    my $persister = {
        class => 'OpenXPKI::Server::Workflow::Persister::Archiver',
        %{ $config->{persister} // {} },
    };

    subtest $testname => sub {
        my $workflow_type = "TESTWORKFLOW".int(rand(2**32));

        #
        # Setup test context
        #
        my $oxitest = OpenXPKI::Test->new(
            with => [ qw( TestRealms ) ],
            also_init => "workflow_factory",
            add_config => {
                "realm.alpha.workflow.persister.Archiver" => $persister,
                "realm.alpha.workflow.def.$workflow_type" => $wf_def,
                "realm.alpha.workflow.def.$workflow_type.field" => $fields,
                "realm.alpha.workflow.def.$workflow_type.attribute" => $attributes,
                "realm.alpha.workflow.def.$workflow_type.state.SUCCESS.output" => ($config->{workflow}->{success_output} // []),
                "realm.alpha.workflow.def.$workflow_type.state.FAILURE.output" => ($config->{workflow}->{failure_output} // []),
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
            $wf1->execute_action("testwf_noop");
        } "execute workflow action";

        if ($force_failure) {
            note "manually failing workflow";
            $wf1->set_failed('entangled something', 'we just saw this...');
        }
        else {
            lives_ok {
                $wf1->execute_action("testwf_noop");
            } "execute workflow action";
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

        cmp_deeply $wf2->attrib, { %{$items->{attribute}}, creator => 'dummy' },
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
    config => {
        # Internal persister defaults:
        #   field: finished
        #   attribute: none
        #   history: archived
        workflow => {
            field => { 'vehicle' => { cleanup => 'none' } },
            attribute => { 'color' => { cleanup => 'finished' } },
            success_output => [ 'temp' ],
        },
    },
    expected => {
        field => {
            'vehicle' => 'plane',
            'temp' => -10,
        },
        attribute => {
            'shoesize'  => 10,
            'hairstyle' => 'bald',
        },
        history => [ qw( testwf_noop testwf_set_context testwf_set_attr testwf_noop ) ],
    };

items_ok "standard cleanup: explicit persister settings", # ... merged with internal defaults
    config => {
        # Internal persister defaults:
        #   field: finished
        persister => {
            cleanup_defaults => {
                attribute => 'finished',
                history => 'finished',
            },
        },
        workflow => {
            attribute => { 'shoesize' => { cleanup => 'none' } },
        },
    },
    expected => {
        field => { },
        attribute => {
            'shoesize' => 10,
        },
        history => [ qw( ) ],
    };

# =============================================================================
# Cleanup upon forced failure
#

items_ok "forced failure: internal defaults",
    force_failure => 1,
    config => {
        # Internal persister defaults:
        #   field: keep
        #   attribute: drop
        #   history: keep
        workflow => {
            field => { 'temp' => { onfail => 'drop' } },
            attribute => { 'shoesize' => { onfail => 'keep' } },
        },
    },
    expected => {
        field => {
            'env' => 'sky',
            'vehicle' => 'plane',
        },
        attribute => {
            'shoesize' => 10,
        },
        # duplicate 'testwf_set_attr' as state FAILURE also logs it as action
        history => [ qw( testwf_noop testwf_set_context testwf_set_attr testwf_set_attr ) ],
   };

items_ok "forced failure: explicit persister settings",
    force_failure => 1,
    config => {
        # Internal persister defaults:
        #   attribute: drop
        persister => {
            onfail_defaults => {
                field => 'drop',
                history => 'drop',
            },
        },
        workflow => {
            field => { 'env' => { onfail => 'keep' } },
            failure_output => [ 'vehicle' ],
        },
    },
    expected => {
        field => {
            'env' => 'sky',
            'vehicle' => 'plane',
        },
        attribute => { },
        # state FAILURE also logs 'testwf_set_attr' as action
        history => [ qw( testwf_set_attr ) ],
   };

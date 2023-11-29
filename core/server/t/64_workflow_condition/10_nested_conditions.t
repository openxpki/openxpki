#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use FindBin qw( $Bin );
use YAML::Tiny;

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;


my $WF_TYPE = "testwf".int(rand(2**32)); # workflow type

#
# Setup test context
#
sub create_test {
    my ($cond_def) = @_;

    my $cfg = YAML::Tiny->read_string("
        head:
            prefix: $WF_TYPE
            persister: Null
        acl:
            User:
                creator: any
        state:
            INITIAL:
                action:
                    - testit > DONE
            DONE:
        action:
            testit:
                class: OpenXPKI::Server::Workflow::Activity::Noop
        condition: {}
    ")->[0];

    $cfg->{condition} = $cond_def;

    # test object
    return OpenXPKI::Test->new(
        with => [ qw( TestRealms ) ],
        also_init => "workflow_factory",
        add_config => {
            "realm.alpha.workflow.def.$WF_TYPE" => $cfg,
        },
    );
}

sub ref_conditions_of {
    my ($name) = @_;
    my $cond = CTX('workflow_factory')->get_factory->get_condition("${WF_TYPE}_$name");
    return $cond->{conditions};
}

sub test ($$) {
    my ($config, $testname) = @_;

    my $cfg_str = $config->{condition};
    my $test_sub = $config->{check};
    my $throws = $config->{throws};

    my $cfg = YAML::Tiny->read_string($cfg_str)->[0];
    my $oxitest;

    subtest $testname => sub {
        if ($throws) {
            throws_ok { create_test($cfg) } $throws, "server should fail with: $throws";
        }
        else {
            lives_ok { $oxitest = create_test($cfg) } 'create test server';
            return unless $oxitest;
            $oxitest->session->data->role('User');
            $test_sub->();
            done_testing;
        }
    };
}

#
# Tests
#
test {
    condition => "
        aaa:
            class: Workflow::Condition::LazyOR
            param:
                condition1: global_something
                condition2: bbb
    ",
    throws => qr/ unkown\ condition .* bbb /msxi,
}, "Fail on unknown (non-prefixed) condition name";

test {
    condition => "
        aaa:
            class: Workflow::Condition::LazyOR
            param:
                condition1: ${WF_TYPE}_bbb
                condition2: '!${WF_TYPE}_bbb'
                condition3: global_something
    ",
    check => sub {
        my $prefix = shift;
        cmp_deeply ref_conditions_of("aaa"), bag("${WF_TYPE}_bbb", "!${WF_TYPE}_bbb", "global_something"), "correctly prefixed conditions";
    },
}, "Leave already prefixed conditions untouched";

test {
    condition => "
        aaa:
            class: Workflow::Condition::LazyOR
            param:
                condition1: bbb
                condition2: '!bbb'
                condition3: global_something
        bbb:
            class: Workflow::Condition::Evaluate
            param:
                test: 1
    ",
    check => sub {
        my $prefix = shift;
        cmp_deeply ref_conditions_of("aaa"), bag("${WF_TYPE}_bbb", "!${WF_TYPE}_bbb", "global_something"), "correctly prefixed conditions";
    },
}, "Auto-prefix local condition (parameter 'condition1')";

test {
    condition => "
        aaa:
            class: Workflow::Condition::LazyOR
            param:
                condition:
                    - bbb
                    - '!bbb'
                    - global_something
        bbb:
            class: Workflow::Condition::Evaluate
            param:
                test: 1
    ",
    check => sub {
        my $prefix = shift;
        cmp_deeply ref_conditions_of("aaa"), bag("${WF_TYPE}_bbb", "!${WF_TYPE}_bbb", "global_something"), "correctly prefixed conditions";
    },
}, "Auto-prefix local condition (parameter 'condition' as ArrayRef)";

test {
    condition => "
        aaa:
            class: Workflow::Condition::LazyOR
            param:
                condition: bbb
        bbb:
            class: Workflow::Condition::Evaluate
            param:
                test: 1
    ",
    check => sub {
        my $prefix = shift;
        cmp_deeply ref_conditions_of("aaa"), bag("${WF_TYPE}_bbb"), "correctly prefixed conditions";
    },
}, "Auto-prefix local condition (parameter 'condition' as scalar)";

done_testing;

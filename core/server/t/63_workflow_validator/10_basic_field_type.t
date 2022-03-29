#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use FindBin qw( $Bin );
use YAML::Tiny;
use File::Temp qw( tempfile );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Validator::BasicFieldType.*'} = 100;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;


my $wf_type; # current workflow type

#
# Setup test context
#
sub create_test {
    my ($param_yaml) = @_;

    # global variable
    $wf_type = "testwf".int(rand(2**32));

    my $cfg = YAML::Tiny->read_string("
        head:
            prefix: $wf_type
            persister: OpenXPKI
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
                input:
                    - myfield
        field:
            myfield:
                name: myfield
    ")->[0];

    $cfg->{field}->{myfield} = {
        %{ $cfg->{field}->{myfield} },
        %{ YAML::Tiny->read_string($param_yaml)->[0] },
    } if $param_yaml;

    # test object
    return OpenXPKI::Test->new(
        with => [ qw( TestRealms ) ],
        also_init => "workflow_factory",
        add_config => {
            "realm.alpha.workflow.def.$wf_type" => $cfg,
        },
    );
}

sub _create_wf {
    my $workflow;

    # Create workflow
    lives_and {
        #$workflow = $oxitest->create_workflow($WORKFLOW_TYPE);
        $workflow = CTX('workflow_factory')->get_factory->create_workflow($wf_type);
        ok ref $workflow;
    } "Create test workflow" or die("Could not create workflow");

    return $workflow;
}

sub _test_field {
    my ($input) = @_;
    my $wf = _create_wf();
    $wf->context->param("myfield" => $input) if defined $input;
    $wf->execute_action("${wf_type}_testit");
}

sub is_valid {
    my ($input) = @_;
    my $input_fmt = defined $input ? "input '$input'" : "empty input";
    lives_ok { _test_field($input) } "$input_fmt is valid";
}

sub validation_fails {
    my ($input, $error) = @_;
    my $input_fmt = defined $input ? "input '$input'" : "empty input";
    throws_ok { _test_field($input) } $error, "$input_fmt raises exception";
}

#
# Tests - FIXME legacy
#

sub test_field_with($$) {
    my ($field_config, $test_cb) = @_;

    # default
    my $oxitest = create_test($field_config);
    $oxitest->session->data->role('User');

    $field_config =~ s/\n/ | /gm;
    subtest "$field_config" => sub {
        $test_cb->();
    };

    $oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $wf_type });
}

# no validation
test_field_with '' => sub {
    is_valid("anything");
    is_valid("");
    is_valid(undef);
};

# REQUIRED
test_field_with 'required: 1' => sub {
    validation_fails(undef, qr/I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID/);
};

# MATCH
test_field_with 'match: ^snow.*$' => sub {
    is_valid(undef);
    is_valid('');
    is_valid('snowflake');
    validation_fails('asnow', qr/I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID/);
    validation_fails('now', qr/I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID/);
};
# UTF-8 does not work
# test_field_with 'match: ^snö٤😃.*$' => sub {
#     is_valid(undef);
#     is_valid('');
#     is_valid('snö٤😃flake');
#     validation_fails('nö٤', qr/I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID/);
# };

# MIN / MAX = array expected
test_field_with "min: 1\nmax: 2" => sub {
    is_valid(undef);
    is_valid([ 'a', 'b' ]);
    validation_fails('', qr/I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID/);
    validation_fails('anything', qr/I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID/);
};

done_testing;

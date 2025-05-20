#!/usr/bin/perl
use strict;
use warnings;
use utf8;

# Core modules
use FindBin qw( $Bin );
use File::Temp qw( tempfile );

# CPAN modules
use Test::More;
use Test::Deep ':v1';
use Test::Exception;
use YAML::PP;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Validator::BasicFieldType.*'} = 32;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;


my $WF_TYPE; # current workflow type
my $FIELD_NAME; # current field name

#
# Setup test context
#
sub create_test {
    my ($field_def) = @_;

    # global variable
    $WF_TYPE = "testwf".int(rand(2**32));

    ($FIELD_NAME) = keys %$field_def;

    my $cfg = YAML::PP->new->load_string("
        head:
            prefix: $WF_TYPE
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
                    - $FIELD_NAME
        field: {}
    ");

    $cfg->{field} = $field_def;

    # test object
    return OpenXPKI::Test->new(
        with => [ qw( TestRealms ) ],
        also_init => "workflow_factory",
        add_config => {
            "realm.alpha.workflow.def.$WF_TYPE" => $cfg,
        },
    );
}

sub _create_wf {
    my $workflow;

    # Create workflow
    lives_and {
        #$workflow = $oxitest->create_workflow($WORKFLOW_TYPE);
        $workflow = CTX('workflow_factory')->get_factory->create_workflow($WF_TYPE);
        ok ref $workflow;
    } "Create test workflow" or die("Could not create workflow");

    return $workflow;
}

sub _test_field {
    my ($input) = @_;
    my $wf = _create_wf();
    $wf->context->param($FIELD_NAME, $input) if defined $input;
    $wf->execute_action("${WF_TYPE}_testit");
}

sub _fmt_input {
    my ($input) = @_;
    return '' unless $input;
    my $input_fmt = join "", map { /[a-z0-9\(\)]/i ? $_ : sprintf '\\x{%02x}', ord $_ } split //, $input;
    return defined $input_fmt ? "input '$input_fmt'" : "empty input";
}

sub is_valid {
    my ($input) = @_;
    lives_ok { _test_field($input) } _fmt_input($input)." is valid";
}

sub validation_fails {
    my ($input, $error) = @_;
    throws_ok { _test_field($input) } $error, _fmt_input($input)." raises exception";
}

#
# Tests
#

sub test_field_with($$) {
    my ($cfg, $test_cb) = @_;

    # default
    my $oxitest = create_test($cfg); # sets $WF_TYPE
    $oxitest->session->data->role('User');

    my $cfg_str = YAML::PP->new->dump_string(values %$cfg);
    $cfg_str =~ s/^---\s+//m;
    $cfg_str =~ s/^\s+//g;
    $cfg_str = join ", ", split /\n/, $cfg_str;

    subtest "$FIELD_NAME = $cfg_str" => sub {
        $test_cb->();
    };

    $oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $WF_TYPE });
}

my $error = qr/I18N_OPENXPKI_UI_VALIDATOR_FIELD_TYPE_INVALID/;

# no validation
test_field_with { myfield => {} }, sub {
    is_valid("anything");
    is_valid("");
    is_valid(undef);
    is_valid("sn\x{00F6}\x{0664}w\x{2150}flake"); # UTF-8
};

# REQUIRED
test_field_with { myfield => { required => 1 } }, sub {
    validation_fails(undef, $error);
};

# MATCH
test_field_with { myfield => { match => '^sn\x{00F6}\x{0664}w\x{2150}.*$' } }, sub {
    is_valid(undef);
    is_valid('');
    is_valid("sn\x{00F6}\x{0664}w\x{2150}flake");
    validation_fails('asnow', $error);
    validation_fails('nö٤w', $error);
};

# MIN / MAX = array expected
test_field_with { myfield => { min => 1, max => 2 } }, sub {
    is_valid(undef);
    is_valid([ 'a', 'b' ]);
    validation_fails('', $error);
    validation_fails('anything', $error);
};

done_testing;

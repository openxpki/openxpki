#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );
use YAML::Tiny;

# CPAN modules
use Test::More tests => 9;
use Test::Deep;
use Test::Exception;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute.*'} = 100;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;


#
# Setup test context
#
sub create_wf_config {
    my ($param_yaml) = @_;

    my $workflow_type = "testwf".int(rand(2**32));

    my $base_config = YAML::Tiny->read_string("
        head:
            prefix: $workflow_type
            persister: OpenXPKI
        acl:
            User:
                creator: any
        state:
            INITIAL:
                action:
                    - pwd_test > DONE
            DONE:
        action:
            pwd_test:
                class: OpenXPKI::Server::Workflow::Activity::Noop
                validator:
                    - password_quality
        validator:
            password_quality:
                class: OpenXPKI::Server::Workflow::Validator::PasswordQuality
                arg:
                    - \$password
    ")->[0];

    $base_config->{validator}->{password_quality}->{param} = YAML::Tiny->read_string($param_yaml)->[0]
        if $param_yaml;

    return ($workflow_type, {
        "realm.alpha.workflow.def.$workflow_type" => $base_config,
    });
}

sub _create_wf {
    my ($workflow_type) = @_;
    my $workflow;

    # Create workflow
    lives_and {
        #$workflow = $oxitest->create_workflow($WORKFLOW_TYPE);
        $workflow = CTX('workflow_factory')->get_factory->create_workflow($workflow_type);
        ok ref $workflow;
    } "Create test workflow" or BAIL_OUT "Could not create workflow";

    return $workflow;
}

sub _pwd_test {
    my ($wf, $pwd, $workflow_type) = @_;
    $wf->context->param("password" => $pwd);
    $wf->execute_action("${workflow_type}_pwd_test");
}

sub password_ok {
    my ($pwd, $workflow_type) = @_;
    subtest "password '$pwd' valid" => sub {
        my $wf = _create_wf($workflow_type);
        lives_ok { _pwd_test($wf, $pwd, $workflow_type) } "validation successful";
    };
}

sub password_fails {
    my ($pwd, $error, $workflow_type) = @_;
    subtest "password '$pwd' fails validation" => sub {
        my $wf = _create_wf($workflow_type);
        throws_ok { _pwd_test($wf, $pwd, $workflow_type) } $error, "validation fails";
    };
}

#
# Tests - FIXME legacy
#

my ($config, $configpart, @wf_types, $wf, $wf_seq, $wf_legacy);
$config = {};

# config 1: legacy
($wf_legacy, $configpart) = create_wf_config('
    minlen: 8
    maxlen: 64
    groups: 2
    dictionary: 4
    following: 4
    following_keyboard: 3
');
push @wf_types, $wf_legacy;
$config = { %$config, %$configpart };

# config 2: default
($wf, $configpart) = create_wf_config('');
push @wf_types, $wf;
$config = { %$config, %$configpart };

# config 3: only check 'sequence'
($wf_seq, $configpart) = create_wf_config('
    checks:
      - sequence
');
push @wf_types, $wf_seq;
$config = { %$config, %$configpart };


my $oxitest = OpenXPKI::Test->new(
#    with => [ qw( TestRealms Workflows ) ],
    with => [ qw( TestRealms ) ],
    also_init => "workflow_factory",
    add_config => $config,
);


password_ok("v.s.pwd4oxi", $wf_legacy);

# too short
password_fails("a2b2g9" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf_legacy);

# too less different characters
password_fails("123456789" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf_legacy);

# contains sequence
password_fails("ab!123456789" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf_legacy);

# repetitive
password_fails("!123aaaabbbbcc" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf_legacy);

#
# Tests - new algorithms
#

# dictionary word
password_fails("troubleshooting" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf);
password_fails(scalar(reverse("troubleshooting")) => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf);

# dictionary word - leet speech
password_fails("p1n3apple1" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf);

# is sequence
password_fails("abcdefghijklmnopqr" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/, $wf_seq);


$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => [ @wf_types ] });

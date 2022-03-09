#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );
use YAML::Tiny;
use File::Temp qw( tempfile );

# CPAN modules
use Test::More tests => 6;
use Test::Deep;
use Test::Exception;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Validator::PasswordQuality.*'} = 100;

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
    } "Create test workflow" or die("Could not create workflow");

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
    subtest "password '$pwd' must fail validation" => sub {
        my $wf = _create_wf($workflow_type);
        throws_ok { _pwd_test($wf, $pwd, $workflow_type) } $error, "validation fails";
    };
}

#
# Tests - FIXME legacy
#

my ($config, $configpart, @wf_types, $wf, $wf_seq, $wf_legacy, $wf_dict);
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

# config 4: only check 'dict' with custom dictionary
my $madeup_dict_word = "!d.4_SuNset";
my ($dict_fh, $dict) = tempfile(UNLINK => 1);
print $dict_fh "$madeup_dict_word\n";
close $dict_fh;

($wf_dict, $configpart) = create_wf_config("
    checks:
      - dict
    dictionaries: /no/file/here , $dict
");
push @wf_types, $wf_seq;
$config = { %$config, %$configpart };


my $oxitest = OpenXPKI::Test->new(
#    with => [ qw( TestRealms Workflows ) ],
    with => [ qw( TestRealms ) ],
    also_init => "workflow_factory",
    add_config => $config,
);

$oxitest->session->data->role('User');

# PLEASE NOTE:
#   More tests regarding password validation are in
#   core/server/t/92_api2_plugins/30_crypto_password_quality.t

#
# Tests - legacy
#

password_ok("vry.s.pwd4oxi", $wf_legacy);

# too less different characters
password_fails("1!111!aaa!!aa" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_DIFFERENT_CHARS/, $wf_legacy);

#
# Tests - new algorithms
#

password_ok("!d.4_sunset", $wf);

# top 10k password
password_fails("scvMOFAS79" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_COMMON_PASSWORD/, $wf);

# is sequence
password_fails("abcdefghijklmnopqr" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_SEQUENCE/, $wf_seq);

# is sequence
password_fails($madeup_dict_word => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_DICT_WORD/, $wf_dict);

$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => [ @wf_types ] });

#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More tests => 4;
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
my $WORKFLOW_TYPE = "TESTWORKFLOW".int(rand(2**32));
my $oxitest = OpenXPKI::Test->new(
#    with => [ qw( TestRealms Workflows ) ],
    with => [ qw( TestRealms ) ],
    also_init => "workflow_factory",
    add_config => {
        "realm.alpha.workflow.def.$WORKFLOW_TYPE" => '
            head:
                prefix: testwf
                persister: OpenXPKI
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
                        - $password
                    param:
                        minlen: 8
                        maxlen: 64
                        groups: 2
                        dictionary: 4
                        following: 3
                        following_keyboard: 3
            acl:
                User:
                    creator: any
        '
    }
);

sub _create_wf {
    my $workflow;

    # Create workflow
    lives_and {
        #$workflow = $oxitest->create_workflow($WORKFLOW_TYPE);
        $workflow = CTX('workflow_factory')->get_factory->create_workflow($WORKFLOW_TYPE);
        ok ref $workflow;
    } "Create test workflow" or BAIL_OUT "Could not create workflow";

    return $workflow;
}

sub _pwd_test {
    my ($wf, $pwd) = @_;
    $wf->context->param("password" => $pwd);
    $wf->execute_action("testwf_pwd_test");
}

sub password_ok {
    my ($pwd) = @_;
    subtest "password '$pwd' valid" => sub {
        my $wf = _create_wf();
        lives_ok { _pwd_test($wf, $pwd) } "validation successful";
    };
}

sub password_fails {
    my ($pwd, $error) = @_;
    subtest "password '$pwd' fails validation" => sub {
        my $wf = _create_wf();
        throws_ok { _pwd_test($wf, $pwd) } $error, "validation fails";
    };
}

#
# Tests
#

password_ok("v.s.pwd4oxi");

# too short
password_fails("a2b2g9" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/);

# too less different characters
password_fails("123456789" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/);

# contains sequence
password_fails("ab!123456789" => qr/I18N_OPENXPKI_UI_PASSWORD_QUALITY_BAD_PASSWORD/);

$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $WORKFLOW_TYPE });

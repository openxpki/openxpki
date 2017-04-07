#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use DateTime;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Test::CertHelper::Database;

plan tests => 1;

#
# Setup test context
#
sub workflow_def {
    my ($name) = @_;
    return {
        'head' => {
            'label' => "$name",
            'persister' => 'OpenXPKI',
            'prefix' => 'motd'
        },
        'state' => {
            'INITIAL' => {
                'action' => 'initialize > PERSIST',
            },
            'PERSIST' => {
                'action' => 'add_message add_link set_motd > SUCCESS',
            },
            'SUCCESS' => {
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_DESCRIPTION',
                'output' => [ 'message', 'link', 'role' ],
            },
        },
        'action' => {
            'initialize' => {
                'class' => 'OpenXPKI::Server::Workflow::Activity::Noop',
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_MOTD_INITIALIZE_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_MOTD_INITIALIZE_DESCRIPTION',
                'input' => [ 'message', 'link', 'role' ],
                'validator' => [
                    'full_uri'
                ],
            },
            'add_message' => {
                'class' => 'OpenXPKI::Server::Workflow::Activity::Tools::WFHash',
                'param' => {
                    'hash_name' => 'motd',
                    'hash_key' => 'message',
                    '_map_hash_value' => '$message'
                }
            },
            'add_link' => {
                'class' => 'OpenXPKI::Server::Workflow::Activity::Tools::WFHash',
                'param' => {
                    'hash_name' => 'motd',
                    'hash_key' => 'href',
                    '_map_hash_value' => '$link'
                }
            },
            'set_motd' => {
                'class' => 'OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry',
                'param' => {
                    'ds_key_param' => 'role',
                    'ds_value_param' => 'motd',
                    'ds_force' => '1',
                    'ds_namespace' => 'webui.motd',
                    'ds_encrypt' => '0',
                },
            },
        },
        'field' => {
            'link' => {
                'name' => 'link',
                'type' => 'text',
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_MOTD_LINK_MESSAGE_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_MOTD_LINK_MESSAGE_DESCRIPTION',
                'placeholder' => 'http://www.openxpki.org/motd',
                'required' => '0',
            },
            'message' => {
                'name' => 'message',
                'type' => 'text',
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_MOTD_FIELD_MESSAGE_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_MOTD_FIELD_MESSAGE_DESCRIPTION',
                'required' => '1',
            },
            'role' => {
                'name' => 'role',
                'type' => 'select',
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_MOTD_FIELD_ROLE_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_MOTD_FIELD_ROLE_DESCRIPTION',
                'option' => { 'item' => [ '_any', 'User', 'RA Operator' ] },
                'required' => '1',
            },
        },
        'validator' => {
            'full_uri' => {
                'class' => 'OpenXPKI::Server::Workflow::Validator::Regex',
                'param' => {
                    'regex' => '\\A http(s)?://[a-zA-Z0-9-\\.]+',
                    'error' => 'I18N_OPENXPKI_UI_WORKFLOW_MOTD_VALIDATOR_LINK_FAILED'
                },
                'arg' => [ '$link' ],
            },
        },
        'acl' => {
            'User' => { 'creator' => 'any' },
        },
    };
};

sub test_wf_instance {
    my ($pki_realm, $name) = @_;
    CTX('session')->set_pki_realm($pki_realm);
    my $wfinfo = CTX('api')->create_workflow_instance({
        WORKFLOW => $name,
        PARAMS => {
            message => "Lucy in the sky with diamonds ($name)",
            link => "http://www.denic.de",
            role => "User",
        },
    });

    die($wfinfo->{'LIST'}->[0]->{'LABEL'} || 'Unknown error occured during workflow creation')
        if $wfinfo and exists $wfinfo->{'SERVICE_MSG'} and $wfinfo->{'SERVICE_MSG'} eq 'ERROR';
}

my $oxitest = OpenXPKI::Test->new;
$oxitest->add_workflow("alpha", "wf_type_1", workflow_def("wf_type_1"));
$oxitest->add_workflow("alpha", "wf_type_2", workflow_def("wf_type_2"));
$oxitest->add_workflow("alpha", "wf_type_3_unused", workflow_def("wf_type_3_unused"));
$oxitest->add_workflow("beta",  "wf_type_4", workflow_def("wf_type_4"));
$oxitest->setup_env(init => [ 'workflow_factory' ]);

CTX('session')->set_user('wilhelm');
CTX('session')->set_role('User');

test_wf_instance "alpha", "wf_type_1";
test_wf_instance "alpha", "wf_type_1";
test_wf_instance "alpha", "wf_type_2";
test_wf_instance "beta",  "wf_type_4";

CTX('session')->set_pki_realm('alpha');

# get_workflow_instance_types
lives_and {
    my $result = CTX('api')->get_workflow_instance_types;
    cmp_deeply $result, {
        wf_type_1 => superhashof({ label => "wf_type_1" }),
        wf_type_2 => superhashof({ label => "wf_type_2" }),
    }, "get_workflow_instance_types() returns current realms' workflows";
}

1;

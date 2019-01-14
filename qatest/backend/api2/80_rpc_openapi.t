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
use Data::UUID;

# Project modules
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;

plan tests => 35;

#
# Setup test context
#
sub workflow_def {
    my ($name, $acl) = @_;
    (my $cleanname = $name) =~ s/[^0-9a-z]//gi;
    return {
        'head' => {
            'label' => $name,
            'persister' => 'OpenXPKI',
            'prefix' => $cleanname,
        },
        'state' => {
            'INITIAL' => {
                'action' => [ 'initialize > PERSIST' ],
            },
            'PERSIST' => {
                'action' => [ 'add_message add_link set_motd > SUCCESS' ],
                'output' => [ 'dummy_arg', ],
            },
            'SUCCESS' => {
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_DESCRIPTION',
                'output' => [ 'message', 'link', 'role' ],
            },
            'FAILURE' => {
                'label' => 'Workflow has failed',
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
            add_message => {
                class => "OpenXPKI::Server::Workflow::Activity::Tools::WFHash",
                input => [ 'dummy_arg' ],
                param => {
                    hash_name => "motd",
                    hash_key => "message",
                    _map_hash_value => '$message',
                },
            },
            add_link => {
                class => "OpenXPKI::Server::Workflow::Activity::Tools::WFHash",
                param => {
                    hash_name => "motd",
                    hash_key => "href",
                    _map_hash_value => '$link',
                },
                label => "Adds the link",
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
            dummy_arg => {
                'name' => 'dummy_arg',
                'type' => 'text',
                'required' => '0',
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
            'User' => { 'creator' => ($acl // 'any') },
            'Guard' => { techlog => 1, history => 1 },
        },
    };
};

my $wf_def_noinit = workflow_def("wf_type_no_initial_action");
$wf_def_noinit->{state}->{INITIAL} = {};

my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( Workflows SampleConfig ) ], # TestRealms
#    add_config => {
#        "realm.alpha.workflow.def.wf_type_1_$uuid" => workflow_def("wf_type_1"),
#        "realm.alpha.workflow.def.wf_type_2_$uuid" => workflow_def("wf_type_2"),
#        "realm.alpha.workflow.def.wf_type_3_unused_$uuid" => workflow_def("wf_type_3_unused"),
#        "realm.alpha.workflow.def.wf_type_no_initial_action_$uuid" => $wf_def_noinit,
#        "realm.beta.workflow.def.wf_type_4_$uuid" => workflow_def("wf_type_4"),
#    },
#    enable_workflow_log => 1, # while testing we do not log to database by default
);

my $params = {
    message => "Lucy in the sky with diamonds",
    link => "http://www.denic.de",
    role => "User",
};

$oxitest->session->data->role("Anonymous");

#
# create_workflow_instance
#
lives_ok {
    my $result = $oxitest->api2_command("get_rpc_openapi_spec" => {
        workflow => "certificate_enroll",
        input => [ qw( pkcs10 comment ) ],
    });
    diag explain $result;
} 'get_rpc_openapi_spec() - xxx';


# delete test workflows
#$oxitest->dbi->start_txn;
#$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => [ -like => "%$uuid" ] } );
#$oxitest->dbi->commit;

1;

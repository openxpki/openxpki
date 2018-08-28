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
#use OpenXPKI::Debug; BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::API2::Plugin::Workflow.*'} = 0b1111111 }
use OpenXPKI::Test;
use OpenXPKI::Test::CertHelper::Database;

plan tests => 6;

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
                'action' => [ 'set_motd > SUCCESS' ],
                'output' => [ 'dummy_arg', ],
            },
            'SUCCESS' => {
                'label' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_LABEL',
                'description' => 'I18N_OPENXPKI_UI_WORKFLOW_SET_MOTD_SUCCESS_DESCRIPTION',
                'output' => [ ],
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
                'input' => [ ],
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
        'acl' => {
            $acl ? ('User' => { 'creator' => $acl }) : (),
            'DieDarf' => { 'creator' => 'any' },
            'Guard' => { techlog => 1, history => 1 },
        },
    };
};

my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms Workflows ) ],
    add_config => {
        "realm.alpha.workflow.def.wf_type_1_any_$uuid" => workflow_def("wf_type_1", "any"),
        "realm.alpha.workflow.def.wf_type_2_self_$uuid" => workflow_def("wf_type_2", "self"),
        "realm.alpha.workflow.def.wf_type_3_others_$uuid" => workflow_def("wf_type_3", "others"),
        "realm.alpha.workflow.def.wf_type_4_regex_$uuid" => workflow_def("wf_type_4", "^edel"),
        "realm.alpha.workflow.def.wf_type_5_noaccess_$uuid" => workflow_def("wf_type_5", undef),
    },
    enable_workflow_log => 1, # while testing we do not log to database by default
);

#
# create_workflow_instance
#
CTX('session')->data->pki_realm("alpha");

CTX('session')->data->role('User');
CTX('session')->data->user('alma');
my $alma_any = $oxitest->create_workflow("wf_type_1_any_$uuid");
my $alma_self = $oxitest->create_workflow("wf_type_2_self_$uuid");
my $alma_others = $oxitest->create_workflow("wf_type_3_others_$uuid");
my $alma_regex = $oxitest->create_workflow("wf_type_4_regex_$uuid"  );

# "superuser" edeltraut
CTX('session')->data->role('DieDarf');
CTX('session')->data->user('edeltraut');
my $edel_any = $oxitest->create_workflow("wf_type_1_any_$uuid");
my $edel_self = $oxitest->create_workflow("wf_type_2_self_$uuid");
my $edel_others = $oxitest->create_workflow("wf_type_3_others_$uuid");
my $edel_regex = $oxitest->create_workflow("wf_type_4_regex_$uuid");
my $edel_noaccess = $oxitest->create_workflow("wf_type_5_noaccess_$uuid");

my $all_ids = [
    $alma_any->id,
    $alma_self->id,
    $alma_others->id,
    $alma_regex->id,
    $edel_any->id,
    $edel_self->id,
    $edel_others->id,
    $edel_regex->id,
    $edel_noaccess->id,
];

#
# search_workflow_instances
#
sub search_result {
    my ($search_param, $expected, $message) = @_;
    lives_and {
        my $result = $oxitest->api2_command("search_workflow_instances" => $search_param);
        cmp_deeply $result, $expected;
    } $message;
}

CTX('session')->data->role('User');
CTX('session')->data->user('alma');

# search without any ACL check
search_result { check_acl => 0, id => $all_ids },
    bag(
        superhashof({ 'workflow_id' => $alma_any->id }),
        superhashof({ 'workflow_id' => $alma_self->id }),
        superhashof({ 'workflow_id' => $alma_others->id }),
        superhashof({ 'workflow_id' => $alma_regex->id }),
        superhashof({ 'workflow_id' => $edel_any->id }),
        superhashof({ 'workflow_id' => $edel_self->id }),
        superhashof({ 'workflow_id' => $edel_others->id }),
        superhashof({ 'workflow_id' => $edel_regex->id }),
        superhashof({ 'workflow_id' => $edel_noaccess->id }),
    ),
     "search_workflow_instances() - no ACL check";

# count workflows
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances_count" => { id => $all_ids });
    is $result, 9;
} "search_workflow_instances_count() - no ACL check";

# search with ACL check
my $query_with_acl_check = { check_acl => 1, id => $all_ids };

search_result $query_with_acl_check,
    bag(
        superhashof({ 'workflow_id' => $alma_any->id }), # ACL 'any' - workflows by all users
        superhashof({ 'workflow_id' => $alma_self->id }), # ACL 'self' - own workflows
        superhashof({ 'workflow_id' => $edel_any->id }), # ACL 'any' - workflows by all users
        superhashof({ 'workflow_id' => $edel_others->id }), # ACL 'others' - workflow by other users
        superhashof({ 'workflow_id' => $edel_regex->id }), # ACL with regex - workflow by matching users
    ),
     "search_workflow_instances() - with ACL check";

# count workflows
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances_count" => $query_with_acl_check);
    is $result, 5;
} "search_workflow_instances_count() - with ACL check";

# search with ACL check but no access to ANY workflow
CTX('session')->data->role('NonExistingRole');
CTX('session')->data->user('fred');

search_result $query_with_acl_check,
    [],
     "search_workflow_instances() - with ACL check and no access to any workflow";

# count workflows
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances_count" => $query_with_acl_check);
    is $result, 0;
} "search_workflow_instances_count() - with ACL check and no access to any workflow";

1;

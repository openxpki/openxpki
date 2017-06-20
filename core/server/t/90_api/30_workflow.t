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

plan tests => 27;

#
# Setup test context
#
sub workflow_def {
    my ($name) = @_;
    return {
        'head' => {
            'label' => $name,
            'persister' => 'OpenXPKI',
            'prefix' => $name,
        },
        'state' => {
            'INITIAL' => {
                'action' => [ 'initialize > PERSIST' ],
            },
            'PERSIST' => {
                'action' => [ 'add_message add_link set_motd > SUCCESS' ],
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
            'User' => { 'creator' => 'any' },
            'Guard' => { techlog => 1, history => 1 },
        },
    };
};

sub test_wf_instance {
    my ($pki_realm, $name) = @_;
    CTX('session')->data->pki_realm($pki_realm);
    my $wfinfo = CTX('api')->create_workflow_instance({
        WORKFLOW => $name,
        PARAMS => {
            message => "Lucy in the sky with diamonds ($name)",
            link => "http://www.denic.de",
            role => "User",
        },
    });

    die($wfinfo->{LIST}->[0]->{LABEL} || 'Unknown error occured during workflow creation')
        if $wfinfo and exists $wfinfo->{SERVICE_MSG} and $wfinfo->{SERVICE_MSG} eq 'ERROR';

    return $wfinfo->{WORKFLOW};
}



use Data::Dumper;


my $oxitest = OpenXPKI::Test->new;
$oxitest->workflow_config("alpha", "wf_type_1", workflow_def("wf_type_1"));
$oxitest->workflow_config("alpha", "wf_type_2", workflow_def("wf_type_2"));
$oxitest->workflow_config("alpha", "wf_type_3_unused", workflow_def("wf_type_3_unused"));
$oxitest->workflow_config("beta",  "wf_type_4", workflow_def("wf_type_4"));
$oxitest->setup_env->init_server('workflow_factory');

CTX('session')->data->role('User');

CTX('session')->data->user('wilhelm');
my $wf_t1_a = test_wf_instance "alpha", "wf_type_1";
CTX('session')->data->user('franz');
my $wf_t1_b = test_wf_instance "alpha", "wf_type_1";
CTX('session')->data->user('wilhelm');
my $wf_t2 =   test_wf_instance "alpha", "wf_type_2";
my $wf_t4 =   test_wf_instance "beta",  "wf_type_4";



CTX('session')->data->pki_realm('alpha');

#diag Dumper(OpenXPKI::Workflow::Config->new->workflow_config);

#
# get_workflow_instance_types
#
lives_and {
    my $result = CTX('api')->get_workflow_instance_types;
    cmp_deeply $result, {
        wf_type_1 => superhashof({ label => "wf_type_1" }),
        wf_type_2 => superhashof({ label => "wf_type_2" }),
    }, "get_workflow_instance_types()";
}

#
# get_workflow_type_for_id
#
lives_and {
    my $result = CTX('api')->get_workflow_type_for_id({ ID => $wf_t1_a->{ID} });
    is $result, "wf_type_1", "get_workflow_type_for_id()";
}

dies_ok {
    my $result = CTX('api')->get_workflow_type_for_id({ ID => -1 });
} "get_workflow_type_for_id() - throw exception if workflow ID is unknown";

#
# execute_workflow_activity
#
throws_ok {
    my $result = CTX('api')->execute_workflow_activity({
        ID => $wf_t1_a->{ID},
        ACTIVITY => "dummy",
    });
} qr/state.*PERSIST.*dummy/i,
    "execute_workflow_activity() - throw exception on unknown activity";

lives_and {
    my $result = CTX('api')->execute_workflow_activity({
        ID => $wf_t1_a->{ID},
        ACTIVITY => "wf_type_1_add_message", # "wf_type_1" is the prefix defined in the workflow
    });
    # ... this will automatically call "add_link" and "set_motd"
    is $result->{WORKFLOW}->{STATE}, 'SUCCESS';
} "execute_workflow_activity() - execute action and transition to new state";

#
# fail_workflow
#
lives_and {
    my $result = CTX('api')->fail_workflow({ ID => $wf_t1_b->{ID} });
    is $result->{WORKFLOW}->{STATE}, 'FAILURE';
} "fail_workflow() - transition to state FAILURE";


#
# Workflow states at this point:
#               proc_state  state       creator     pki_realm
#   $wf_t1_a    finished    SUCCESS     wilhelm     alpha
#   $wf_t1_b    finished    FAILURE     franz       alpha
#   $wf_t2      manual      PERSIST     wilhelm     alpha
#   $wf_t4      manual      PERSIST     wilhelm     beta
#


#
# get_workflow_log
#
throws_ok { CTX('api')->get_workflow_log({ ID => $wf_t1_a->{ID} }) } qr/unauthorized/i,
    "get_workflow_log() - throw exception on unauthorized user";

CTX('session')->data->role('Guard');
lives_and {
    my $result = CTX('api')->get_workflow_log({ ID => $wf_t1_a->{ID} });
    my $i = -1;
    $i = -2 if $result->[$i]->[2] =~ / during .* startup /msxi;
    like $result->[$i]->[2], qr/ execute .* initialize /msxi or diag explain $result;

    # Check sorting
    my $prev_ts = '30000101120000000000'; # year 3000
    my $sorting_ok = 1;
    for (@{$result}) {
        my ($timestamp, $priority, $message) = @$_;
        $sorting_ok = 0 if ($timestamp cmp $prev_ts) > 0; # messages should get older down the list
        $prev_ts = $timestamp;
    }
    is $sorting_ok, 1;
} "get_workflow_log() - return 'save' as first message and sort correctly";
CTX('session')->data->role('User');

#
# get_workflow_history
#
CTX('session')->data->role('Guard');
lives_and {
    my $result = CTX('api')->get_workflow_history({ ID => $wf_t1_a->{ID} });
    cmp_deeply $result, [
        superhashof({ WORKFLOW_STATE => "INITIAL", WORKFLOW_ACTION => re(qr/create/i) }),
        superhashof({ WORKFLOW_STATE => "INITIAL", WORKFLOW_ACTION => re(qr/initialize/i) }),
        superhashof({ WORKFLOW_STATE => "PERSIST", WORKFLOW_ACTION => re(qr/add_message/i) }),
        superhashof({ WORKFLOW_STATE => re(qr/^PERSIST/), WORKFLOW_ACTION => re(qr/add_link/i) }),
        superhashof({ WORKFLOW_STATE => re(qr/^PERSIST/), WORKFLOW_ACTION => re(qr/set_motd/i) }),
    ];
} "get_workflow_history()";
CTX('session')->data->role('User');

#
# get_workflow_creator
#
lives_and {
    my $result = CTX('api')->get_workflow_creator({ ID => $wf_t1_a->{ID} });
    is $result, "wilhelm";
} "get_workflow_creator()";


#
# get_workflow_activities
#
lives_and {
    my $result = CTX('api')->get_workflow_activities({
        WORKFLOW => "wf_type_2",
        ID => $wf_t2->{ID},
    });
    cmp_deeply $result, [
        "wf_type_2_add_message",
    ];
} "get_workflow_activities()";

#
# get_workflow_activities_params
#
lives_and {
    my $result = CTX('api')->get_workflow_activities_params({
        WORKFLOW => "wf_type_2",
        ID => $wf_t2->{ID},
    });
    cmp_deeply $result, [
        "wf_type_2_add_message",
        [
            superhashof({ name => "dummy_arg", requirement => "optional" }),
        ],
    ];
} "get_workflow_activities_params()";

#
# search_workflow_instances
#
sub search_result {
    my ($search_param, $expected, $message) = @_;
    lives_and {
        my $result = CTX('api')->search_workflow_instances($search_param);
        cmp_deeply $result, $expected;
    } $message;
}

my $wf_t1_a_data = superhashof({
    'WORKFLOW.WORKFLOW_TYPE' => $wf_t1_a->{TYPE},
    'WORKFLOW.WORKFLOW_SERIAL' => $wf_t1_a->{ID},
    'WORKFLOW.WORKFLOW_STATE' => 'SUCCESS',
});

my $wf_t1_b_data = superhashof({
    'WORKFLOW.WORKFLOW_TYPE' => $wf_t1_b->{TYPE},
    'WORKFLOW.WORKFLOW_SERIAL' => $wf_t1_b->{ID},
    'WORKFLOW.WORKFLOW_STATE' => 'FAILURE',
});

my $wf_t2_data = superhashof({
    'WORKFLOW.WORKFLOW_TYPE' => $wf_t2->{TYPE},
    'WORKFLOW.WORKFLOW_SERIAL' => $wf_t2->{ID},
    'WORKFLOW.WORKFLOW_STATE' => 'PERSIST',
});

my $wf_t4_data = superhashof({
    'WORKFLOW.WORKFLOW_TYPE' => $wf_t4->{TYPE},
    'WORKFLOW.WORKFLOW_SERIAL' => $wf_t4->{ID},
    'WORKFLOW.WORKFLOW_STATE' => 'PERSIST',
});

search_result { SERIAL => [ $wf_t1_a->{ID}, $wf_t2->{ID} ] },
    bag($wf_t1_a_data, $wf_t2_data),
    "search_workflow_instances() - search by SERIAL";

# TODO Tests: Remove superbagof() constructs below once we have a clean test database

search_result { ATTRIBUTE => [ { KEY => "creator", VALUE => "franz" } ] },
    all(
        superbagof($wf_t1_b_data),                                                  # expected record
        array_each(superhashof({ 'WORKFLOW.WORKFLOW_TYPE' => $wf_t1_b->{TYPE} })),  # make sure we got no other types (=other creators)
    ),
    "search_workflow_instances() - search by ATTRIBUTE";

search_result { TYPE => [ "wf_type_1", "wf_type_2" ] },
    superbagof($wf_t1_a_data, $wf_t1_b_data, $wf_t2_data),
    "search_workflow_instances() - search by TYPE (ArrayRef)";

search_result { TYPE => "wf_type_2" },
    all(
        superbagof($wf_t2_data),                                                    # expected record
        array_each(superhashof({ 'WORKFLOW.WORKFLOW_TYPE' => $wf_t2->{TYPE} })),    # make sure we got no other types
    ),
    "search_workflow_instances() - search by TYPE (String)";

search_result { STATE => [ "PERSIST", "SUCCESS" ] },
    all(
        superbagof($wf_t1_a_data, $wf_t2_data),                                     # expected record
        array_each(superhashof({ 'WORKFLOW.WORKFLOW_STATE' => code(sub{ shift !~ /^FAILED$/ }) })), # unwanted records
    ),
    "search_workflow_instances() - search by STATE (ArrayRef)";

search_result { STATE => "FAILURE" },
    all(
        superbagof($wf_t1_b_data),                                                  # expected record
        array_each(superhashof({ 'WORKFLOW.WORKFLOW_STATE' => "FAILURE" })),        # make sure we got no other states
    ),
    "search_workflow_instances() - search by STATE (String)";

search_result { PKI_REALM => "beta" },
    all(
        superbagof($wf_t4_data),                                                    # expected record
        array_each(superhashof({ 'WORKFLOW.PKI_REALM' => "beta" })),                # make sure we got no other realms
    ),
    "search_workflow_instances() - search by PKI_REALM";

# Check descending order (by ID)
lives_and {
    my $result = CTX('api')->search_workflow_instances({ PKI_REALM => "alpha" });
    BAIL_OUT("Test impossible as query gave less than 2 results") unless scalar @{$result} > 1;
    my $prev_id;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if ($prev_id and $_->{'WORKFLOW.WORKFLOW_SERIAL'} >= $prev_id);
        $prev_id = $_->{'WORKFLOW.WORKFLOW_SERIAL'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering by ID descending (default)";

# Check reverse (ascending) order by ID
lives_and {
    my $result = CTX('api')->search_workflow_instances({ PKI_REALM => "alpha", REVERSE => 0 });
    my $prev_id;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if $prev_id and $_->{'WORKFLOW.WORKFLOW_SERIAL'} <= $prev_id;
        $prev_id = $_->{'WORKFLOW.WORKFLOW_SERIAL'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering by ID ascending (= not reversed)";

# Check custom order by TYPE
lives_and {
    my $result = CTX('api')->search_workflow_instances({ PKI_REALM => "alpha", ORDER => "WORKFLOW.WORKFLOW_TYPE" });
    my $prev_type;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if $prev_type and ($_->{'WORKFLOW.WORKFLOW_TYPE'} cmp $prev_type) > 0;
        $prev_type = $_->{'WORKFLOW.WORKFLOW_TYPE'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering by custom TYPE";

search_result
    {
        SERIAL => [ $wf_t1_a->{ID}, $wf_t1_b->{ID}, $wf_t2->{ID} ],
        LIMIT => 2,
    },
    [ $wf_t2_data, $wf_t1_b_data ],
    "search_workflow_instances() - search with LIMIT";

search_result
    {
        SERIAL => [ $wf_t1_a->{ID}, $wf_t1_b->{ID}, $wf_t2->{ID} ],
        START => 1, LIMIT => 2,
    },
    [ $wf_t1_b_data, $wf_t1_a_data ],
    "search_workflow_instances() - search with LIMIT and START";

search_result
    {
        SERIAL => [ $wf_t1_a->{ID}, $wf_t1_b->{ID}, $wf_t2->{ID} ],
        ATTRIBUTE => [ { KEY => "creator", VALUE => "wilhelm" } ],
        STATE => [ "SUCCESS", "FAILURE" ],
    },
    [ $wf_t1_a_data ],
    "search_workflow_instances() - complex query";

#
# search_workflow_instances_count
#
lives_and {
    my $result = CTX('api')->search_workflow_instances_count({ SERIAL => [ $wf_t1_a->{ID}, $wf_t1_b->{ID}, $wf_t2->{ID} ] });
    is $result, 3;
} "search_workflow_instances_count()";

1;

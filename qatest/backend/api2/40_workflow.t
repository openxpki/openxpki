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
use lib "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;
use OpenXPKI::Test::CertHelper::Database;

plan tests => 40;

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

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms Workflows ) ],
    add_config => {
        "realm.alpha.workflow.def.wf_type_1" => workflow_def("wf_type_1"),
        "realm.alpha.workflow.def.wf_type_2" => workflow_def("wf_type_2"),
        "realm.alpha.workflow.def.wf_type_3_unused" => workflow_def("wf_type_3_unused"),
        "realm.alpha.workflow.def.wf_type_no_initial_action" => $wf_def_noinit,
        "realm.alpha.workflow.def.wf_type_5_restricted" => workflow_def("wf_type_5", "self"),
        "realm.beta.workflow.def.wf_type_4" => workflow_def("wf_type_4"),
    },
);
# while testing we do not log to database by default
$oxitest->enable_workflow_log;

sub test_wf_instance {
    my ($pki_realm, $name) = @_;
    CTX('session')->data->pki_realm($pki_realm);

    my $wfinfo;
    lives_and {
        $wfinfo = $oxitest->api2_command("create_workflow_instance" => {
            workflow => $name,
            params => {
                message => "Lucy in the sky with diamonds ($name)",
                link => "http://www.denic.de",
                role => "User",
            },
        });

        BAIL_OUT($wfinfo->{LIST}->[0]->{LABEL} || 'Unknown error occured during workflow creation')
            if $wfinfo and exists $wfinfo->{SERVICE_MSG} and $wfinfo->{SERVICE_MSG} eq 'ERROR';

        like $wfinfo->{workflow}->{id}, qr/^\d+$/;
    } "create_workflow_instance() - creates test workflow '$name'";

    return $wfinfo->{workflow};
}

#
# create_workflow_instance
#
CTX('session')->data->role('User');

CTX('session')->data->user('wilhelm');
my $wf_t1_a = test_wf_instance "alpha", "wf_type_1";
CTX('session')->data->user('franz');
my $wf_t1_b = test_wf_instance "alpha", "wf_type_1";
CTX('session')->data->user('wilhelm');
my $wf_t2 =   test_wf_instance "alpha", "wf_type_2";
my $wf_t4 =   test_wf_instance "beta",  "wf_type_4";
CTX('session')->data->user('edeltraut');
my $wf_t5 =   test_wf_instance "alpha", "wf_type_5_restricted";

throws_ok {
    CTX('session')->data->pki_realm("alpha");
    $oxitest->api2_command("create_workflow_instance" => {
        workflow => "wf_type_no_initial_action",
        params => {
            message => "Lucy in the sky with diamonds",
            link => "http://www.denic.de",
            role => "User",
        },
    });
} qr/first activity/, 'create_workflow_instance() - throws exception if workflow lacks initial action';


CTX('session')->data->pki_realm('alpha');

#diag Dumper(OpenXPKI::Workflow::Config->new->workflow_config);

#
# get_workflow_instance_types
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_instance_types");
    cmp_deeply $result, {
        wf_type_1 => superhashof({ label => "wf_type_1" }),
        wf_type_2 => superhashof({ label => "wf_type_2" }),
        wf_type_2 => superhashof({ label => "wf_type_2" }),
        wf_type_5_restricted => superhashof({ label => "wf_type_5" }),
    }, "get_workflow_instance_types()";
}

#
# get_workflow_type_for_id
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_type_for_id" => { id => $wf_t1_a->{id} });
    is $result, "wf_type_1", "get_workflow_type_for_id()";
}

dies_ok {
    my $result = $oxitest->api2_command("get_workflow_type_for_id" => { id => -1 });
} "get_workflow_type_for_id() - throw exception if workflow ID is unknown";

#
# execute_workflow_activity
#
throws_ok {
    my $result = $oxitest->api2_command("execute_workflow_activity" => {
        id => $wf_t1_a->{id},
        activity => "dummy",
    });
} qr/state.*PERSIST.*dummy/i,
    "execute_workflow_activity() - throw exception on unknown activity";

lives_and {
    my $result = $oxitest->api2_command("execute_workflow_activity" => {
        id => $wf_t1_a->{id},
        activity => "wftype1_add_message", # "wftype1" is the prefix defined in the workflow
    });
    # ... this will automatically call "add_link" and "set_motd"
    is $result->{workflow}->{state}, 'SUCCESS';
} "execute_workflow_activity() - execute action and transition to new state";

#
# fail_workflow
#
lives_and {
    my $result = $oxitest->api2_command("fail_workflow" => { id => $wf_t1_b->{id} });
    is $result->{workflow}->{state}, 'FAILURE';
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
# list_workflow_titles
#
lives_and {
    my $result = $oxitest->api2_command("list_workflow_titles");
    cmp_deeply $result, superhashof({
        'wf_type_1'         => { label => ignore(), description => ignore(), },
        'wf_type_2'         => { label => ignore(), description => ignore(), },
        'wf_type_3_unused'  => { label => ignore(), description => ignore(), },
    });
} "list_workflow_titles()";

#
# get_workflow_info
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_info" => { id => $wf_t2->{id} });
    cmp_deeply $result, {
        workflow => superhashof({
            id => re(qr/^\d+$/),
            count_try => re(qr/^\d+$/),
            context => {
                workflow_id => $wf_t2->{id},
                role => 'User',
                creator => 'wilhelm',
                creator_role => 'User',
                link => 'http://www.denic.de',
                message => 'Lucy in the sky with diamonds (wf_type_2)',
                wf_current_action => 'wftype2_initialize',
            },
            last_update => ignore(),
            proc_state => 'manual',
            reap_at => re(qr/^\d+$/),
            state => 'PERSIST',
            type => 'wf_type_2',
            wake_up_at => ignore(),
            description => ignore(),
            label => 'wf_type_2',
        }),
        state => {
            button => {},
            option => [ 'wftype2_add_message' ],
            output => [
                {
                    name => 'dummy_arg',
                    type => 'text',
                    required => 0,
                },
            ],
        },
        activity => {
            wftype2_add_message => {
                label => 'wftype2_add_message',
                name => 'wftype2_add_message',
                field => [
                    {
                        name => 'dummy_arg',
                        required => '0',
                        type => 'text',
                        clonable => 0,
                    },
                ],
            },
        },
        handles => [],
    };
} "get_workflow_info() - via ID";

lives_and {
    my $result = $oxitest->api2_command("get_workflow_info" => { id => $wf_t2->{id}, activity => 'wftype2_add_link' });
    cmp_deeply $result, superhashof({
        activity => {
            wftype2_add_link => {
                label => 'Adds the link',
                name => 'wftype2_add_link',
            },
        },
    });
} "get_workflow_info() - via ID with given ACTIVITY";

lives_and {
    my $result = $oxitest->api2_command("get_workflow_info" => { id => $wf_t2->{id}, with_attributes => 1 });
    cmp_deeply $result, superhashof({
        workflow => superhashof({
            attribute => superhashof({
                creator => 'wilhelm',
            }),
        }),
    });
} "get_workflow_info() - via ID with ATTRIBUTE = 1";

#
# get_workflow_base_info
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_base_info" => { type => $wf_t2->{type} });
    cmp_deeply $result, {
        workflow => superhashof({
            id => re(qr/^\d+$/),
            state => 'INITIAL',
            type => 'wf_type_2',
            description => ignore(),
            label => 'wf_type_2',
        }),
        state => {
            button => {},
            option => [ 'wftype2_initialize' ],
        },
        activity => {
            wftype2_initialize => superhashof({
                name => 'wftype2_initialize',
                label => 'I18N_OPENXPKI_UI_WORKFLOW_ACTION_MOTD_INITIALIZE_LABEL',
                field => ignore(),
            }),
        },
    };
} "get_workflow_base_info() - via TYPE";

#
# get_workflow_log
#
throws_ok { $oxitest->api2_command("get_workflow_log" => { id => $wf_t1_a->{id} }) } qr/unauthorized/i,
    "get_workflow_log() - throw exception on unauthorized user";

CTX('session')->data->role('Guard');
lives_and {
    my $result = $oxitest->api2_command("get_workflow_log" => { id => $wf_t1_a->{id} });
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
    my $result = $oxitest->api2_command("get_workflow_history" => { id => $wf_t1_a->{id} });
    cmp_deeply $result, [
        superhashof({ workflow_state => "INITIAL", workflow_action => re(qr/create/i) }),
        superhashof({ workflow_state => "INITIAL", workflow_action => re(qr/initialize/i) }),
        superhashof({ workflow_state => "PERSIST", workflow_action => re(qr/add_message/i) }),
        superhashof({ workflow_state => re(qr/^PERSIST/), workflow_action => re(qr/add_link/i) }),
        superhashof({ workflow_state => re(qr/^PERSIST/), workflow_action => re(qr/set_motd/i) }),
    ];
} "get_workflow_history()";
CTX('session')->data->role('User');

#
# get_workflow_creator
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_creator" => { id => $wf_t1_a->{id} });
    is $result, "wilhelm";
} "get_workflow_creator()";


#
# get_workflow_activities
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_activities" => {
        workflow => "wf_type_2",
        id => $wf_t2->{id},
    });
    cmp_deeply $result, [
        "wftype2_add_message",
    ];
} "get_workflow_activities()";

#
# get_workflow_activities_params
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_activities_params" => {
        workflow => "wf_type_2",
        id => $wf_t2->{id},
    });
    cmp_deeply $result, [
        "wftype2_add_message",
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
        my $result = $oxitest->api2_command("search_workflow_instances" => $search_param);
        cmp_deeply $result, $expected;
    } $message;
}

my $wf_t1_a_data = superhashof({
    'workflow_type' => $wf_t1_a->{type},
    'workflow_id' => $wf_t1_a->{id},
    'workflow_state' => 'SUCCESS',
});

my $wf_t1_b_data = superhashof({
    'workflow_type' => $wf_t1_b->{type},
    'workflow_id' => $wf_t1_b->{id},
    'workflow_state' => 'FAILURE',
});

my $wf_t2_data = superhashof({
    'workflow_type' => $wf_t2->{type},
    'workflow_id' => $wf_t2->{id},
    'workflow_state' => 'PERSIST',
});

my $wf_t4_data = superhashof({
    'workflow_type' => $wf_t4->{type},
    'workflow_id' => $wf_t4->{id},
    'workflow_state' => 'PERSIST',
});

search_result { id => [ $wf_t1_a->{id}, $wf_t1_b->{id}, $wf_t2->{id} ] },
    bag($wf_t1_a_data, $wf_t1_b_data, $wf_t2_data),
    "search_workflow_instances() - search by ID";

# TODO Tests: Remove superbagof() constructs below once we have a clean test database

search_result { attribute => [ { KEY => "creator", VALUE => "franz" } ] },
    all(
        superbagof($wf_t1_b_data),                                                  # expected record
        array_each(superhashof({ 'workflow_type' => $wf_t1_b->{type} })),  # make sure we got no other types (=other creators)
    ),
    "search_workflow_instances() - search by ATTRIBUTE";

search_result { type => [ "wf_type_1", "wf_type_2" ] },
    superbagof($wf_t1_a_data, $wf_t1_b_data, $wf_t2_data),
    "search_workflow_instances() - search by TYPE (ArrayRef)";

search_result { type => "wf_type_2" },
    all(
        superbagof($wf_t2_data),                                                    # expected record
        array_each(superhashof({ 'workflow_type' => $wf_t2->{type} })),    # make sure we got no other types
    ),
    "search_workflow_instances() - search by TYPE (String)";

search_result { state => [ "PERSIST", "SUCCESS" ] },
    all(
        superbagof($wf_t1_a_data, $wf_t2_data),                                     # expected record
        array_each(superhashof({ 'workflow_state' => code(sub{ shift !~ /^FAILED$/ }) })), # unwanted records
    ),
    "search_workflow_instances() - search by STATE (ArrayRef)";

search_result { state => "FAILURE" },
    all(
        superbagof($wf_t1_b_data),                                                  # expected record
        array_each(superhashof({ 'workflow_state' => "FAILURE" })),        # make sure we got no other states
    ),
    "search_workflow_instances() - search by STATE (String)";

search_result { pki_realm => "beta" },
    all(
        superbagof($wf_t4_data),                                                    # expected record
        array_each(superhashof({ 'pki_realm' => "beta" })),                # make sure we got no other realms
    ),
    "search_workflow_instances() - search by PKI_REALM";

# Check descending order (by ID)
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances" => { pki_realm => "alpha" });
    BAIL_OUT("Test impossible as query gave less than 2 results") unless scalar @{$result} > 1;
    my $prev_id;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if ($prev_id and $_->{'workflow_id'} >= $prev_id);
        $prev_id = $_->{'workflow_id'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering by ID descending (default)";

# Check reverse (ascending) order by ID
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances" => { pki_realm => "alpha", reverse => 0 });
    my $prev_id;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if $prev_id and $_->{'workflow_id'} <= $prev_id;
        $prev_id = $_->{'workflow_id'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering by ID ascending (= not reversed)";

# Check custom order by TYPE
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances" => { pki_realm => "alpha", order => "WORKFLOW_TYPE" });
    my $prev_type;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if $prev_type and ($_->{'workflow_type'} cmp $prev_type) > 0;
        $prev_type = $_->{'workflow_type'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering by custom TYPE";

search_result
    {
        id => [ $wf_t1_a->{id}, $wf_t1_b->{id}, $wf_t2->{id} ],
        limit => 2,
    },
    [ $wf_t2_data, $wf_t1_b_data ],
    "search_workflow_instances() - search with LIMIT";

search_result
    {
        id => [ $wf_t1_a->{id}, $wf_t1_b->{id}, $wf_t2->{id} ],
        start => 1, limit => 2,
    },
    [ $wf_t1_b_data, $wf_t1_a_data ],
    "search_workflow_instances() - search with LIMIT and START";

search_result
    {
        id => [ $wf_t1_a->{id}, $wf_t1_b->{id}, $wf_t2->{id} ],
        attribute => [ { KEY => "creator", VALUE => "wilhelm" } ],
        state => [ "SUCCESS", "FAILURE" ],
    },
    [ $wf_t1_a_data ],
    "search_workflow_instances() - complex query";

TODO: {
    local $TODO = "Parameter 'check_acl' to search_workflow_instances() does not work properly.";

    # check_acl (edeltraut should see her workflow)
    CTX('session')->data->user('edeltraut');
    search_result { check_acl => 1 },
            any( superhashof({ 'workflow_type' => $wf_t5->{type} }) ),
         "search_workflow_instances() - search with CHECK_ACL part 1";
};

# check_acl (user wilhelm should not see edeltrauts workflow)
CTX('session')->data->user('wilhelm');
search_result { check_acl => 1 },
    array_each( superhashof({ 'workflow_type' => re(qr/^(.*)$/, noneof($wf_t5->{type})) }) ),
     "search_workflow_instances() - search with CHECK_ACL part 2";

#
# search_workflow_instances_count
#
note "Sleep two seconds to give workflow persister time to write to DB";
sleep 2;
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances_count" => { id => [ $wf_t1_a->{id}, $wf_t1_b->{id}, $wf_t2->{id} ] });
    is $result, 3;
} "search_workflow_instances_count()";

1;

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
use OpenXPKI::Test::CertHelper::Database;

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
                    'key' => 'role',
                    'value' => 'motd',
                    'force' => '1',
                    'namespace' => 'webui.motd',
                    'encrypt' => '0',
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
            'User' => { creator => ($acl // 'any'), fail => 1, resume => 1, wakeup => 1, archive => 1, attribute => 1 },
            'Guard' => { techlog => 1, history => 1 },
        },
    };
};

my $wf_def_noinit = workflow_def("wf_type_no_initial_action");
$wf_def_noinit->{state}->{INITIAL} = {};

my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms Workflows ) ],
    add_config => {
        "realm.alpha.workflow.def.wf_type_1_$uuid" => workflow_def("wf_type_1"),
        "realm.alpha.workflow.def.wf_type_2_$uuid" => workflow_def("wf_type_2"),
        "realm.alpha.workflow.def.wf_type_3_unused_$uuid" => workflow_def("wf_type_3_unused"),
        "realm.alpha.workflow.def.wf_type_no_initial_action_$uuid" => $wf_def_noinit,
        "realm.beta.workflow.def.wf_type_4_$uuid" => workflow_def("wf_type_4"),
    },
    enable_workflow_log => 1, # while testing we do not log to database by default
);

my $params = {
    message => "Lucy in the sky with diamonds",
    link => "http://www.denic.de",
    role => "User",
};

#
# create_workflow_instance
#
CTX('session')->data->role('User');

CTX('session')->data->pki_realm("alpha");

CTX('session')->data->user('wilhelm');
my $wf_t1_sync =   $oxitest->create_workflow("wf_type_1_$uuid", $params);
my $wf_t1_async1 = $oxitest->create_workflow("wf_type_1_$uuid", $params);
my $wf_t1_async2 = $oxitest->create_workflow("wf_type_1_$uuid", $params);

CTX('session')->data->user('franz');
my $wf_t1_fail = $oxitest->create_workflow("wf_type_1_$uuid", $params);

CTX('session')->data->user('wilhelm');
my $wf_t2 =   $oxitest->create_workflow("wf_type_2_$uuid", $params);

CTX('session')->data->pki_realm("beta");
my $wf_t4 =   $oxitest->create_workflow("wf_type_4_$uuid", $params);

throws_ok {
    CTX('session')->data->pki_realm("alpha");
    $oxitest->api2_command("create_workflow_instance" => {
        workflow => "wf_type_no_initial_action_$uuid",
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
    cmp_deeply $result, superhashof({
        $wf_t1_sync->type => superhashof({ label => "wf_type_1" }),
        $wf_t2->type      => superhashof({ label => "wf_type_2" }),
    });
} "get_workflow_instance_types()";

#
# get_workflow_type_for_id
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_type_for_id" => { id => $wf_t1_sync->id });
    is $result, $wf_t1_sync->type;
} "get_workflow_type_for_id()";

dies_ok {
    my $result = $oxitest->api2_command("get_workflow_type_for_id" => { id => -1 });
} "get_workflow_type_for_id() - throw exception if workflow ID is unknown";

#
# execute_workflow_activity - SYNCHRONOUS
#
throws_ok {
    my $result = $oxitest->api2_command("execute_workflow_activity" => {
        id => $wf_t1_sync->id,
        activity => "dummy",
    });
} qr/state.*PERSIST.*dummy/i,
    "execute_workflow_activity() - throw exception on unknown activity";

lives_and {
    my $result = $oxitest->api2_command("execute_workflow_activity" => {
        id => $wf_t1_sync->id,
        activity => "wftype1_add_message", # "wftype1" is the prefix defined in the workflow
    });
    # ... this will automatically call "add_link" and "set_motd"
    is $result->{workflow}->{state}, 'SUCCESS';
} "execute_workflow_activity() - synchronous execution";

#
# execute_workflow_activity - ASYNCHRONOUS
#
lives_and {
    my $result = $oxitest->api2_command("execute_workflow_activity" => {
        id => $wf_t1_async1->id,
        activity => "wftype1_add_message", # "wftype1" is the prefix defined in the workflow
        async => 1,
        wait => 1,
    });
    # ... this will automatically call "add_link" and "set_motd"
    is $result->{workflow}->{state}, 'SUCCESS';
} "execute_workflow_activity() - asynchronous execution (blocking mode)";

lives_and {
    my $info = $oxitest->api2_command("execute_workflow_activity" => {
        id => $wf_t1_async2->id,
        activity => "wftype1_add_message", # "wftype1" is the prefix defined in the workflow
        async => 1,
    });
    # ... this will automatically call "add_link" and "set_motd"

    my $timeout = time + 6;
    while (time < $timeout) {
        $info = $oxitest->api2_command("get_workflow_info" => { id => $wf_t1_async2->id });
        last if $info->{workflow}->{state} eq "SUCCESS";
        sleep 1;
    }
    is $info->{workflow}->{state}, "SUCCESS";
} "execute_workflow_activity() - asynchronous execution (nonblocking mode)";

#
# fail_workflow
#
lives_and {
    my $result = $oxitest->api2_command("fail_workflow" => { id => $wf_t1_fail->id });
    is $result->{workflow}->{state}, 'FAILURE';
} "fail_workflow() - transition to state FAILURE";


#
# Workflow states at this point:
#               proc_state  state       creator     pki_realm
#   $wf_t1_sync    finished    SUCCESS     wilhelm     alpha
#   $wf_t1_fail    finished    FAILURE     franz       alpha
#   $wf_t2      manual      PERSIST     wilhelm     alpha
#   $wf_t4      manual      PERSIST     wilhelm     beta
#


#
# list_workflow_titles
#
lives_and {
    my $result = $oxitest->api2_command("list_workflow_titles");
    cmp_deeply $result, superhashof({
        $wf_t1_sync->type         => { label => ignore(), description => ignore(), },
        $wf_t2->type              => { label => ignore(), description => ignore(), },
        "wf_type_3_unused_$uuid"  => { label => ignore(), description => ignore(), },
    });
} "list_workflow_titles()";

#
# get_workflow_info
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_info" => { id => $wf_t2->id, with_ui_info => 1 });
    cmp_deeply $result, {
        workflow => superhashof({
            id => re(qr/^\d+$/),
            count_try => re(qr/^\d+$/),
            context => {
                workflow_id => $wf_t2->id,
                role => 'User',
                creator => 'wilhelm',
                link => 'http://www.denic.de',
                message => 'Lucy in the sky with diamonds',
            },
            last_update => ignore(),
            proc_state => 'manual',
            reap_at => re(qr/^\d+$/),
            state => 'PERSIST',
            type => $wf_t2->type,
            wake_up_at => ignore(),
            archive_at => ignore(),
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
        handles => [ 'fail', 'attribute' ],
    };
} "get_workflow_info() - via ID";

lives_and {
    my $result = $oxitest->api2_command("get_workflow_info" => { id => $wf_t2->id, with_ui_info => 1, activity => 'wftype2_add_link' });
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
    my $result = $oxitest->api2_command("get_workflow_info" => { id => $wf_t2->id, with_attributes => 1 });
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
    my $result = $oxitest->api2_command("get_workflow_base_info" => { type => $wf_t2->type });
    cmp_deeply $result, {
        workflow => superhashof({
            id => re(qr/^\d+$/),
            state => 'INITIAL',
            type => $wf_t2->type,
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
throws_ok { $oxitest->api2_command("get_workflow_log" => { id => $wf_t1_sync->id }) } qr/no permission/i,
    "get_workflow_log() - throw exception on unauthorized user";

CTX('session')->data->role('Guard');

subtest "get_workflow_log()" => sub {
    plan tests => 4;

    my $result;
    lives_ok {
        $result = $oxitest->api2_command("get_workflow_log" => { id => $wf_t1_sync->id });
    } 'get_workflow_log() - testing workflow #' . $wf_t1_sync->id;

    isnt scalar @$result, 0, "log has at least one entry";

    # remove noisy message that occurs since Workflow 1.53
    my @clean_log = grep { $_->[2] ne 'Using standard field class' } @$result;

    # check first message
    my $i = -1;
    $i = -2 if $clean_log[$i]->[2] =~ / during .* startup /msxi;
    like $clean_log[$i]->[2], qr/ execute .* initialize /msxi, "'initialize' is the first (second) message"
        or diag explain \@clean_log;

    # Check sorting
    my $prev_ts = 4294967295; # 2106-02-07T06:28:15
    my $sorting_ok = 1;
    for (@{$result}) {
        my ($timestamp, $priority, $message) = @$_;
        $sorting_ok = 0 if $timestamp > $prev_ts; # messages should get older down the list
        $prev_ts = $timestamp;
    }
    is $sorting_ok, 1, "log is sorted correctly";
};

CTX('session')->data->role('User');

#
# get_workflow_history
#
CTX('session')->data->role('Guard');
lives_and {
    my $result = $oxitest->api2_command("get_workflow_history" => { id => $wf_t1_sync->id });
    cmp_deeply $result, [
        superhashof({ workflow_state => "INITIAL", workflow_action => re(qr/initialize/i) }),
        superhashof({ workflow_state => "PERSIST", workflow_action => re(qr/add_message/i) }),
        superhashof({ workflow_state => re(qr/^PERSIST/), workflow_action => re(qr/add_link/i) }),
        superhashof({ workflow_state => re(qr/^PERSIST/), workflow_action => re(qr/set_motd/i) }),
    ] or diag explain $result;
} "get_workflow_history()";
CTX('session')->data->role('User');

#
# get_workflow_creator
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_creator" => { id => $wf_t1_sync->id });
    is $result, "wilhelm";
} "get_workflow_creator()";


#
# get_workflow_activities
#
lives_and {
    my $result = $oxitest->api2_command("get_workflow_activities" => {
        id => $wf_t2->id,
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
        id => $wf_t2->id,
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

my $wf_t1_sync_data = superhashof({
    'workflow_type' => $wf_t1_sync->type,
    'workflow_id' => $wf_t1_sync->id,
    'workflow_state' => 'SUCCESS',
});

my $wf_t1_fail_data = superhashof({
    'workflow_type' => $wf_t1_fail->type,
    'workflow_id' => $wf_t1_fail->id,
    'workflow_state' => 'FAILURE',
});

my $wf_t2_data = superhashof({
    'workflow_type' => $wf_t2->type,
    'workflow_id' => $wf_t2->id,
    'workflow_state' => 'PERSIST',
});

my $wf_t4_data = superhashof({
    'workflow_type' => $wf_t4->type,
    'workflow_id' => $wf_t4->id,
    'workflow_state' => 'PERSIST',
});

search_result { id => [ $wf_t1_sync->id, $wf_t1_fail->id, $wf_t2->id ] },
    bag($wf_t1_sync_data, $wf_t1_fail_data, $wf_t2_data),
    "search_workflow_instances() - search by ID";

# TODO Tests: Remove superbagof() constructs below once we have a clean test database

search_result { type => $wf_t1_fail->type, attribute => [ { KEY => "creator", VALUE => "franz" } ] },
    all(
        superbagof($wf_t1_fail_data),                                       # expected record
        array_each(superhashof({ 'workflow_type' => $wf_t1_fail->type })),  # make sure we got no other types (=other creators)
    ),
    "search_workflow_instances() - search by ATTRIBUTE";

search_result { type => [ $wf_t1_sync->type, $wf_t2->type ] },
    superbagof($wf_t1_sync_data, $wf_t1_fail_data, $wf_t2_data),
    "search_workflow_instances() - search by TYPE (ArrayRef)";

search_result { type => $wf_t2->type },
    all(
        superbagof($wf_t2_data),                                                    # expected record
        array_each(superhashof({ 'workflow_type' => $wf_t2->type })),    # make sure we got no other types
    ),
    "search_workflow_instances() - search by TYPE (String)";

search_result { state => [ "PERSIST", "SUCCESS" ] },
    all(
        superbagof($wf_t1_sync_data, $wf_t2_data),                                     # expected record
        array_each(superhashof({ 'workflow_state' => code(sub{ shift !~ /^FAILED$/ }) })), # unwanted records
    ),
    "search_workflow_instances() - search by STATE (ArrayRef)";

search_result { state => "FAILURE" },
    all(
        superbagof($wf_t1_fail_data),                                                  # expected record
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
    die("Test impossible as query gave less than 2 results") unless scalar @{$result} > 1;
    my $prev_id;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if ($prev_id and $_->{'workflow_id'} >= $prev_id);
        $prev_id = $_->{'workflow_id'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering with defaults (ID, descending)";

# Check reverse (ascending) order by ID
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances" => { pki_realm => "alpha", reverse => 0 });
    my $prev_id;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if ($prev_id and $_->{'workflow_id'} <= $prev_id);
        $prev_id = $_->{'workflow_id'};
    }
    is $sorting_ok, 1;
} "search_workflow_instances() - result ordering by default column, ascending";

# Check custom order by last update, ascending
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances" => { pki_realm => "alpha", order => "workflow_last_update" });
    my $prev_val;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if ($prev_val and ($prev_val cmp $_->{'workflow_last_update'}) > 0);
        $prev_val = $_->{'workflow_last_update'};
    }
    is $sorting_ok, 1 or diag explain $result;
} "search_workflow_instances() - result ordering by custom column, ascending";

# Check custom order by last update, dewscending
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances" => { pki_realm => "alpha", order => "workflow_last_update", reverse => 1 });
    my $prev_val;
    my $sorting_ok = 1;
    for (@{$result}) {
        $sorting_ok = 0 if ($prev_val and ($prev_val cmp $_->{'workflow_last_update'}) < 0);
        $prev_val = $_->{'workflow_last_update'};
    }
    is $sorting_ok, 1 or diag explain $result;
} "search_workflow_instances() - result ordering by custom column, descending";

search_result
    {
        id => [ $wf_t1_sync->id, $wf_t1_fail->id, $wf_t2->id ],
        limit => 2,
    },
    [ $wf_t2_data, $wf_t1_fail_data ],
    "search_workflow_instances() - search with LIMIT";

search_result
    {
        id => [ $wf_t1_sync->id, $wf_t1_fail->id, $wf_t2->id ],
        start => 1, limit => 2,
    },
    [ $wf_t1_fail_data, $wf_t1_sync_data ],
    "search_workflow_instances() - search with LIMIT and START";

search_result
    {
        id => [ $wf_t1_sync->id, $wf_t1_fail->id, $wf_t2->id ],
        attribute => [ { KEY => "creator", VALUE => "wilhelm" } ],
        state => [ "SUCCESS", "FAILURE" ],
    },
    [ $wf_t1_sync_data ],
    "search_workflow_instances() - complex query";

#
# search_workflow_instances_count
#
lives_and {
    my $result = $oxitest->api2_command("search_workflow_instances_count" => { id => [ $wf_t1_sync->id, $wf_t1_fail->id, $wf_t2->id ] });
    is $result, 3;

} "search_workflow_instances_count()";

# delete test workflows
$oxitest->dbi->start_txn;
$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => [ -like => "%$uuid" ] } );
$oxitest->dbi->commit;

1;

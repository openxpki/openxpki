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

plan tests => 1;

my $tests = {
    '\A [a-zA-Z0-9] [a-zA-Z0-9-]* (\.[a-zA-Z0-9-]*[a-zA-Z0-9])* \z' => {
        type => 'string',
        description => ignore(),
        pattern => '^[a-zA-Z0-9][a-zA-Z0-9-]*(\.[a-zA-Z0-9-]*[a-zA-Z0-9])*$',
    },
    '.* octal \001' => {
        type => 'string',
        description => re(qr/octal/),
    },
    '\A \Q blah \E \z' => {
        type => 'string',
        description => re(qr/\\A \\Q blah \\E \\z/),
    },
    '\A a\\\\  b\ c  d\\\\  e\\\\ \  f\ \ g \z' => {
        type => 'string',
        description => ignore(),
        pattern => '^a\\\\b cd\\\\e\\\\ f  g$',
    },
};

my $fieldname_by_perlre = {};

my $wf_fields = {
    map {
        my $name = Data::UUID->new->create_str;
        $fieldname_by_perlre->{$_} = $name;

        $name => { match => $_ }
    }
    keys %$tests
};

my $expected_input_schema = {
    map {
        my $name = $fieldname_by_perlre->{$_};
        my $schema = $tests->{$_};

        $name => $schema
    }
    keys %$tests
};

#
# Setup test context
#
sub workflow_def {
    my ($name, $wf_fields) = @_;
    (my $cleanname = $name) =~ s/[^0-9a-z]//gi;
    return {
        head => {
            label => $name,
            description => "$name blah",
            persister => 'OpenXPKI',
            prefix => $cleanname,
        },
        state => {
            'INITIAL' => {
                action => [ 'initialize > SUCCESS' ],
            },
            'SUCCESS' => {
                label => 'success label',
                description => 'success description',
                output => [ 'message' ],
            },
            'FAILURE' => {
                label => 'Workflow has failed',
            },
        },
        action => {
            'initialize' => {
                class => 'OpenXPKI::Server::Workflow::Activity::Noop',
                input => [ keys %$wf_fields ],
            },
        },
        field => $wf_fields,
        acl => {
            'User' => { 'creator' => 'any' },
            'Guard' => { techlog => 1, history => 1 },
        },
    };
};

# create workflow
my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs
my $wf_name = 'wf_type_1';
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( Workflows TestRealms ) ],
    add_config => {
        "realm.alpha.workflow.def.${wf_name}_$uuid" => workflow_def($wf_name, $wf_fields),
    },
#    enable_workflow_log => 1, # while testing we do not log to database by default
);

# query OpenAPI spec
lives_and {
    my $result = $oxitest->api2_command("get_rpc_openapi_spec" => {
        workflow => "${wf_name}_$uuid",
        input => [ values %$fieldname_by_perlre ],
        output => [], # "role" should be ignored because workflow does not define it as output
    });
    cmp_deeply $result, {
        description => "${wf_name} blah",
        input_schema => {
            type => 'object',
            properties => $expected_input_schema,
        },
        output_schema => ignore(),
    } or diag explain $result;
} 'get_rpc_openapi_spec() - various regular expressions (field parameter "match")';


# delete test workflows
$oxitest->dbi->start_txn;
$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => [ -like => "%$uuid" ] } );
$oxitest->dbi->commit;

1;

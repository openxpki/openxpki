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

#
# Setup test context
#
sub workflow_def {
    my ($name) = @_;
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
                input => [ 'message', 'size', 'role' ],
            },
        },
        field => {
            'message' => {
                name => 'message',
                type => 'text',
                label => 'message label',
                min => 1,
                max => 5,
                required => '1',
            },
            'size' => {
                name => 'size',
                api_type => 'Integer(minimum:5)',
                label => 'size label',
                required => '0',
            },
            'role' => {
                name => 'role',
                type => 'select',
                label => 'role label',
                option => { 'item' => [ '_any', 'User', 'RA Operator' ] },
                required => '1',
            },
        },
        acl => {
            'User' => { 'creator' => 'any' },
            'Guard' => { techlog => 1, history => 1 },
        },
    };
};

my $uuid = Data::UUID->new->create_str; # so we don't see workflows from previous test runs

my $oxitest = OpenXPKI::Test->new(
    with => [ qw( Workflows TestRealms ) ],
    add_config => {
        "realm.alpha.workflow.def.wf_type_1_$uuid" => workflow_def("wf_type_1"),
    },
#    enable_workflow_log => 1, # while testing we do not log to database by default
);

#
# create_workflow_instance
#
lives_and {
    my $result = $oxitest->api2_command("get_rpc_openapi_spec" => {
        workflow => "wf_type_1_$uuid",
        input => [ qw( message size role ) ],
        output => [ qw( message role ) ], # "role" should be ignored because workflow does not define it as output
    });
    cmp_deeply $result, {
        description => "wf_type_1 blah",
        input_schema => {
            type => 'object',
            properties => {
                'message' => {
                    description => 'message label',
                    type => 'array',
                    items => { type => 'string', },
                },
                'size' => {
                    description => 'size label',
                    type => 'integer',
                    minimum => 5,
                },
                'role' => {
                    description => 'role label',
                    type => 'string'
                },
            },
            required => [ 'message', 'role' ],
        },
        output_schema => {
            type => 'object',
            properties => {
                'message' => {
                    description => 'message label',
                    type => 'array',
                    items => { type => 'string', },
                },
                'role' => {
                    description => 'role label',
                    type => 'string'
                },
            },
            required => [ 'message', 'role' ],
        }
    } or diag explain $result;
} 'get_rpc_openapi_spec() - xxx';


# delete test workflows
$oxitest->dbi->start_txn;
$oxitest->dbi->delete(from => 'workflow', where => { workflow_type => [ -like => "%$uuid" ] } );
$oxitest->dbi->commit;

1;

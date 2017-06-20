#!/usr/bin/perl
use strict;
use warnings;

# Core modules
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Deep;
use Test::Exception;
use Data::UUID;

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute.*'} = 100;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Test;

plan tests => 5;

#
# Setup test context
#
my $workflow_type = "TESTWORKFLOW".int(rand(2**32));
my $oxitest = OpenXPKI::Test->new;
$oxitest->realm_config("alpha", "workflow.def.$workflow_type" => {
    head => { prefix => "testwf", persister => 'OpenXPKI' },
    state => {
        INITIAL => { action => [ 'doit > DONE' ] },
        DONE    => { },
    },
    action => {
        doit => {
            class => 'OpenXPKI::Server::Workflow::Activity::Tools::SetAttribute',
            param => {
                shoesize => 10,
                hairstyle => undef,
            },
        },
    },
    acl => { Anonymous => { creator => 'any' } },
});
$oxitest->setup_env;
$oxitest->init_server('workflow_factory');

sub insert_meta_attribute {
    my ($db, $wf_id, $key, $value) = @_;
    $db->insert_and_commit(
        into => 'workflow_attributes',
        values => {
            workflow_id => $wf_id,
            attribute_contentkey => $key,
            attribute_value => $value,
        }
    );
}

#
# Tests
#
my $workflow;

# Create workflow
lives_and {
    $workflow = CTX('workflow_factory')->get_factory->create_workflow($workflow_type);
    ok ref $workflow;
} "Create test workflow";

# Insert the workflow attributes to be changed
insert_meta_attribute($oxitest->dbi, $workflow->id, shoesize  => 9);
insert_meta_attribute($oxitest->dbi, $workflow->id, color     => 'blue');
insert_meta_attribute($oxitest->dbi, $workflow->id, hairstyle => 'bald');

# Run action that updates the attributes
lives_ok {
    $workflow->execute_action("testwf_doit");
} "Execute workflow action";

# Check database entries
my $meta = $oxitest->dbi->select(
    from => 'workflow_attributes',
    columns => [ '*' ],
    where => { workflow_id => $workflow->id }
)->fetchall_arrayref({});

cmp_deeply $meta, bag(
    superhashof({ attribute_contentkey => 'shoesize',  attribute_value => '10' }),
    superhashof({ attribute_contentkey => 'color',     attribute_value => 'blue' }),

    # TODO This entry should be deleted - see https://github.com/openxpki/openxpki/issues/527
    superhashof({ attribute_contentkey => 'hairstyle', attribute_value => 'bald' }),

), "Correctly updated database" or diag explain $meta;

# Refetch workflow
my $workflow_dup;
lives_and {
    $workflow_dup = CTX('workflow_factory')->get_factory->fetch_workflow($workflow_type, $workflow->id);
    ok ref $workflow_dup;
} "Refetch workflow from database";

# Test attributes
lives_and {
    my $attrs = $workflow_dup->attrib;
    cmp_deeply $attrs, {
        shoesize  => 10,
        color     => 'blue',
        # TODO This entry should be deleted - see https://github.com/openxpki/openxpki/issues/527
        hairstyle => 'bald',
    };
} "Attributes are correctly set";

$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $workflow_type });
$oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => $workflow->id });

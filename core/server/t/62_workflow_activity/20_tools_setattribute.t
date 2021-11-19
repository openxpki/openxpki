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
my $oxitest = OpenXPKI::Test->new(
    with => [ qw( TestRealms ) ],
    also_init => "workflow_factory",
    add_config => {
        "realm.alpha.workflow.def.$workflow_type" => {
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
            acl => { PrincesOfTheUniverse => { creator => 'any' } },
        },
    },
);

$oxitest->session->data->role("PrincesOfTheUniverse");

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
} "Create test workflow" or die("Could not create workflow");

# Insert the workflow attributes to be changed
$workflow->attrib({
    creator => 'dummy', # OpenXPKI::Workflow::Factory->can_access_workflow() needs it set
    shoesize => 9,
    color => 'blue',
    hairstyle => 'bald',
});
$workflow->save_initial(); # also saves attributes ("creator"!)

# Run action that updates the attributes
lives_ok {
    $workflow->execute_action("testwf_doit");
} "Execute workflow action";

# Check database entries
my $meta = $oxitest->dbi->select_hashes(
    from => 'workflow_attributes',
    columns => [ '*' ],
    where => { workflow_id => $workflow->id }
);

cmp_deeply $meta, bag(
    superhashof({ attribute_contentkey => 'creator',   attribute_value => 'dummy' }),
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
        creator   => 'dummy',
        shoesize  => 10,
        color     => 'blue',
        # TODO This entry should be deleted - see https://github.com/openxpki/openxpki/issues/527
        hairstyle => 'bald',
    };
} "Attributes are correctly set";

$oxitest->dbi->delete_and_commit(from => 'workflow', where => { workflow_type => $workflow_type });
$oxitest->dbi->delete_and_commit(from => 'workflow_attributes', where => { workflow_id => $workflow->id });

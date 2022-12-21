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

#use OpenXPKI::Debug;
#$OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata'} = 100;
#$OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::API2::Plugin::Cert::set_cert_metadata'} = 100;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # to get AUTO_ID
use OpenXPKI::Test;

plan tests => 3;

#
# Setup test context
#
my $cert_id = Data::UUID->new->create_b64;

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
                    class => 'OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata',
                },
            },
            acl => { PrincesOfTheUniverse => { creator => 'any' } },
        },
    },
);

$oxitest->session->data->role("PrincesOfTheUniverse");

# Prepare DB
sub insert_meta_attribute {
    my ($db, $cert_id, $key, $value) = @_;
    $db->insert_and_commit(
        into => 'certificate_attributes',
        values => {
            identifier => $cert_id,
            attribute_key => AUTO_ID,
            attribute_contentkey => $key,
            attribute_value => $value,
        }
    );
}

insert_meta_attribute($oxitest->dbi, $cert_id, meta_shoesize  => 9);
insert_meta_attribute($oxitest->dbi, $cert_id, meta_color     => 'blue');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_hairstyle => 'bald');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_cars      => 'bmw');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_cars      => 'ford');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_cars      => 'horch');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_birds     => 'magpie');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_birds     => 'crow');

#
# Tests
#
my $workflow;

# Create workflow
lives_and {
    $workflow = CTX('workflow_factory')->get_factory->create_workflow($workflow_type);
    ok ref $workflow;
} "Create test workflow" or die("Could not create workflow");

# Run action that updates the attributes
lives_ok {
    $workflow->context->param(cert_identifier => $cert_id);
    $workflow->context->param(meta_color      => 'red');
    $workflow->context->param({ meta_hairstyle => undef }); # setting to "undef" only works when passing a HashRef
    $workflow->context->param(meta_cars       => ['horch', 'tesla']);
    $workflow->context->param(meta_birds      => []);
    $workflow->context->param(meta_morphosis  => 'butterfly');
    $workflow->context->param(meta_physics    => [ 'transcendency', 'ontology' ]);

    $workflow->execute_action("testwf_doit");
} "Execute workflow action";

lives_and {
    my $meta = $oxitest->dbi->select_hashes(
        from => 'certificate_attributes',
        columns => [ '*' ],
        where => { identifier => $cert_id }
    );

    cmp_deeply $meta, bag(
        superhashof({ attribute_contentkey => 'meta_shoesize',  attribute_value => '9' }),
        superhashof({ attribute_contentkey => 'meta_color',     attribute_value => 'red' }),
        superhashof({ attribute_contentkey => 'meta_cars',      attribute_value => 'horch' }),
        superhashof({ attribute_contentkey => 'meta_cars',      attribute_value => 'tesla' }),
        superhashof({ attribute_contentkey => 'meta_morphosis', attribute_value => 'butterfly' }),
        superhashof({ attribute_contentkey => 'meta_physics',   attribute_value => 'transcendency' }),
        superhashof({ attribute_contentkey => 'meta_physics',   attribute_value => 'ontology' }),
    ) or diag explain $meta;
} "Correctly updated database";

$oxitest->dbi->delete_and_commit(from => 'certificate_attributes', where => { identifier => $cert_id });

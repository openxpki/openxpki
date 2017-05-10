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

#use OpenXPKI::Debug; $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata.*'} = 32;

# Project modules
use lib "$Bin/../lib";
use lib "$Bin";
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Database; # to get AUTO_ID
use OpenXPKI::Test;
use OpenXPKI::Test::WorkflowMock;

plan tests => 4;

# TODO Change test to start real workflow similar to 20_tools_setattribute.t

#
# Setup test context
#
my $oxitest = OpenXPKI::Test->new->setup_env->init_server;

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

my $cert_id = Data::UUID->new->create_b64;

# Prepare DB
insert_meta_attribute($oxitest->dbi, $cert_id, meta_shoesize  => 9);
insert_meta_attribute($oxitest->dbi, $cert_id, meta_color     => 'blue');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_hairstyle => 'bald');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_cars      => 'bmw');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_cars      => 'ford');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_cars      => 'horch');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_birds     => 'magpie');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_birds     => 'crow');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_equal     => 'same');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_equal     => 'same');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_equal2    => 'yo');
insert_meta_attribute($oxitest->dbi, $cert_id, meta_equal2    => 'yo');

# Prepare workflow context
my $wf = OpenXPKI::Test::WorkflowMock->new;
$wf->context->param(cert_identifier   => $cert_id);
$wf->context->param(meta_color        => 'red');
$wf->context->param({ meta_hairstyle  => undef }); # setting to "undef" only works when passing a HashRef
$wf->context->param('meta_cars[]'     => ['horch', 'tesla']);
$wf->context->param('meta_birds[]'    => []);
$wf->context->param(meta_morphosis    => 'butterfly');
$wf->context->param('meta_physics[]'  => [ 'transcendency', 'ontology' ]);
$wf->context->param('meta_equal[]'    => [ 'same', 'same' ]);
$wf->context->param('meta_equal2[]'   => [ 'yo' ]);
$wf->context->param('meta_equal_nu[]' => [ 'this', 'this' ]);

#
# Tests
#
use_ok "OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata";

my $activity;
lives_ok {
    $activity = OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata->new(
        $wf,
        {},
    );
} "Create activity object";

lives_ok {
    CTX('dbi')->start_txn; # can't use $oxitest->dbi->dbh as the called method for some reason gets a new CTX('dbi') connection
    $activity->execute($wf);
    CTX('dbi')->commit;
} "Execute activity";

lives_and {
    my $meta = $oxitest->dbi->select(
        from => 'certificate_attributes',
        columns => [ '*' ],
        where => { identifier => $cert_id }
    )->fetchall_arrayref({});

    cmp_deeply $meta, bag(
        superhashof({ attribute_contentkey => 'meta_shoesize',  attribute_value => '9' }),
        superhashof({ attribute_contentkey => 'meta_color',     attribute_value => 'red' }),
        superhashof({ attribute_contentkey => 'meta_cars',      attribute_value => 'horch' }),
        superhashof({ attribute_contentkey => 'meta_cars',      attribute_value => 'tesla' }),
        superhashof({ attribute_contentkey => 'meta_morphosis', attribute_value => 'butterfly' }),
        superhashof({ attribute_contentkey => 'meta_physics',   attribute_value => 'transcendency' }),
        superhashof({ attribute_contentkey => 'meta_physics',   attribute_value => 'ontology' }),
        superhashof({ attribute_contentkey => 'meta_equal',     attribute_value => 'same' }),
        superhashof({ attribute_contentkey => 'meta_equal',     attribute_value => 'same' }),
        superhashof({ attribute_contentkey => 'meta_equal2',    attribute_value => 'yo' }),
        superhashof({ attribute_contentkey => 'meta_equal_nu',  attribute_value => 'this' }),
        superhashof({ attribute_contentkey => 'meta_equal_nu',  attribute_value => 'this' }),
    );
} "Correctly updated database";

$oxitest->dbi->delete_and_commit(from => 'certificate_attributes', where => { identifier => $cert_id });

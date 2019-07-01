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

# Project modules
use lib $Bin, "$Bin/../../lib", "$Bin/../../../core/server/t/lib";
use OpenXPKI::Test;
use OpenXPKI::Serialization::Simple;

plan tests => 8;


#
# Init helpers
#
my $oxitest = OpenXPKI::Test->new(
    with => [qw( SampleConfig Workflows WorkflowCreateCert )],
    #log_level => 'debug',
);
my $cert = $oxitest->create_cert(
    profile => "I18N_OPENXPKI_PROFILE_TLS_SERVER",
    hostname => "fun",
    requestor_gname => 'Sarah',
    requestor_name => 'Dessert',
    requestor_email => 'sahar@d-sert.d',
);
my $cert_id = $cert->{identifier};

#
# Tests
#
my $wf;
lives_ok {
    $wf = $oxitest->create_workflow('change_metadata' => { cert_identifier => $cert_id }, 1);
} "create workflow: change_metadata";

$wf->state_is('DATA_UPDATE');

my $serializer = OpenXPKI::Serialization::Simple->new();
$wf->execute('metadata_update_context' => {
    'meta_email'     => $serializer->serialize( ['uli.update@openxpki.de' ]),
    'meta_requestor' => 'Uli Update',
    'meta_system_id' => '',
});
$wf->state_is('CHOOSE_ACTION');

$wf->execute('metadata_persist');
$wf->state_is('SUCCESS');

my $info = $oxitest->api_command('get_cert_attributes' => { IDENTIFIER => $cert_id });
cmp_deeply $info, superhashof({
    meta_email     => [ 'uli.update@openxpki.de' ],
    meta_requestor => [ "Uli Update" ],
}), "confirm changed metadata via API";

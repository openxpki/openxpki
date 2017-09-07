#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 3;

package main;

my $result;
my $client = TestCGI::factory();

# create temp dir
-d "tmp/" || mkdir "tmp/";

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_revocation_request_v2',
});

is($result->{main}->[0]->{content}->{fields}->[5]->{name}, 'wf_token');

my $cert_identifier = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<tmp/pkiclient.id';
    <$HANDLE>;
};

diag('Start revocation for ' . $cert_identifier);

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_identifier' => $cert_identifier,
    'reason_code' => 'unspecified',
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

diag("Revoking pkiclient, cert identifier $cert_identifier, Workflow Id $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!crr_update_crr!wf_id!'.$wf_id,
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_identifier' => $cert_identifier,
    'reason_code' => 'unspecified',
    'invalidity_time' => time(),
    'comment' => 'Extra comment',
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!crr_submit!wf_id!'.$wf_id,
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!crr_approve_crr!wf_id!'.$wf_id,
});

is ($result->{status}->{level}, 'info', 'Status is paused (waiting for revocation)');


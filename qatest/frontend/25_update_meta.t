#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 7;

package main;

my $result;
my $client = TestCGI::factory('democa');

# Load cert status page using cert identifier
my $cert_identifier = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, "<tmp/entity12.id";
    <$HANDLE>;
};

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!change_metadata',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_identifier' => $cert_identifier,
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

note("Workflow Id is $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'meta_email' =>  [ 'mail1@openxpki.org',  'mail2@openxpki.org' ],
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!metadata_persist!wf_id!' . $wf_id,
});

is ($result->{status}->{level}, 'success', 'Status is success');

is( ref $result->{main}->[0]->{content}->{data}->[2]->{value}, 'ARRAY');
is( scalar @{$result->{main}->[0]->{content}->{data}->[2]->{value}}, 2);
is( $result->{main}->[0]->{content}->{data}->[2]->{value}->[1], 'mail2@openxpki.org');

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!show_metadata',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_identifier' => $cert_identifier,
});

is( ref $result->{main}->[0]->{content}->{data}->[0]->{value}, 'ARRAY');
is( scalar @{$result->{main}->[0]->{content}->{data}->[0]->{value}}, 2);

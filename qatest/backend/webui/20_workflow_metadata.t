#!/usr/bin/perl

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use strict;
use warnings;
use CGI::Session;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use MockUI;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 6;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::UI' );
}

require_ok( 'OpenXPKI::Client::UI' );

my $log = Log::Log4perl->get_logger();

my $session = new CGI::Session(undef, undef, {Directory=>'/tmp'});
my $session_id = $session->id;
ok ($session->id, 'Session id ok');

my $buffer = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<', '/tmp/webui.json';
    <$HANDLE>;
};

$buffer = JSON->new->decode($buffer);

my $cert_identifier = $buffer->{cert_identifier};

my $result;
my $client = MockUI::factory();

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
    'meta_email' =>  'mail1@openxpki.org',
});

$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!metadata_persist!wf_id!' . $wf_id,
});


is ($result->{status}->{level}, 'success', 'Status is success');
is( $result->{main}->[0]->{content}->{data}->[3]->{value}, 'mail1@openxpki.org', 'data validated');


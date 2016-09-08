#!/usr/bin/perl 

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 2;

package main;

my $result;
my $client = TestCGI::factory(); 

my @cert_identifier;
for my $cert (('entity','entity2','pkiclient')) {
 
    diag('Revoke '  .$cert);       
    # Load cert status page using cert identifier
    my $cert_identifier = do { # slurp
        local $INPUT_RECORD_SEPARATOR;
        open my $HANDLE, "<tmp/$cert.id";
        <$HANDLE>;
    };
    
    push @cert_identifier, $cert_identifier;

}

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!certificate_bulk_revoke',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'cert_identifier_list' => join("\n", @cert_identifier),
    'reason_code' => 'unspecified',
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

diag("Cleanup / Bulk Revoke Workflow Id $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});


$result = $client->mock_request({
    'action' => 'workflow!select!wf_action!crrbulk_approve_crr!wf_id!'.$wf_id,
});
  
is ($result->{status}->{level}, 'success', 'Status is success');

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

my $cert_identifier = do { # slurp
    local $INPUT_RECORD_SEPARATOR;
    open my $HANDLE, '<tmp/entity.id';
    <$HANDLE>;
};
chomp $cert_identifier;

# Search revocation workflow created by scep replace workflow
$result = $client->mock_request({
    'action' => 'workflow!search',
    'wf_creator' => '',
    'wf_proc_state' => 'pause',
    'wf_type' => 'certificate_revocation_request_v2',
    'meta_cert_subject' => 'entity.openxpki.org',
});

$result = $client->mock_request({
    page => $result->{goto},
});

my @certlist = @{$result->{main}->[0]->{content}->{data}};
ok(scalar @certlist);
CERTLIST:
while (my $line = shift @certlist) {
   
    $result = $client->mock_request({
        # load the workflow and check for the correct cert identifier
        page => sprintf("workflow!load!wf_id!%01d!view!context", $line->[0])
    });
    
    foreach my $data (@{$result->{main}->[0]->{content}->{data}}) {
        next unless($data->{label} eq 'cert_identifier');
        next unless($data->{value}->{label} eq $cert_identifier);
        
        ok (1, "Found workflow");
              
        is($result->{right}->[0]->{content}->{data}->[2]->{value}, "CHECK_FOR_DELAYED_REVOKE", "State is delayed revoke");
        
        last CERTLIST;
    }
}
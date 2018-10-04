#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 5;

package main;

my $result;
my $client = TestCGI::factory();

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!crl_issuance',
});

is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
});

like($result->{goto}, qr/workflow!load!wf_id!\d+/, 'Got redirect');

my ($wf_id) = $result->{goto} =~ /workflow!load!wf_id!(\d+)/;

diag("Workflow Id is $wf_id");

$result = $client->mock_request({
    'page' => $result->{goto},
});

is ($result->{status}->{level}, 'success', 'Status is success');

# get crl id

my $crlid = $result->{main}->[0]->{content}->{data}->[0]->{value}->[0]->{value} || '';

like($crlid, "/[0-9]+/",'Got CRL Id');

# download crl as text
$result = $client->mock_request({
     'page' => "crl!download!crl_key!$crlid!format!txt"
});

ok($result, 'CRL is not empty');

open(CERT, ">tmp/crl.txt");
print CERT $result ;
close CERT;

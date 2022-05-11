#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;

use Test::More tests => 4;

package main;

my $result;
my $client = TestCGI::factory('democa');

$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!crl_issuance',
});

is $client->has_field('wf_token'), 1, 'field "wf_token" present';

$result = $client->run_action('workflow', { 'force_issue' => 1 });

# while ($client->last_result->{refresh}) {
#     note "got 'refresh' - waiting 2 seconds";
#     sleep 2;
#     $client->mock_request({ 'page' => $client->last_result->{refresh}->{href} });
# }

my $crl_page = $result->{main}->[0]->{content}->{data}->[0]->{value}->[0]->{page} || '';
ok $crl_page, 'got CRL page';
my $crlid = pop @{[split("!", $crl_page)]};

like $crlid, "/[0-9]+/",'got CRL Id';

# download crl as text
$result = $client->mock_request({
     'page' => "crl!download!crl_key!$crlid!format!txt"
});

ok($result, 'CRL is not empty');

open(CERT, ">tmp/crl.txt");
print CERT $result ;
close CERT;

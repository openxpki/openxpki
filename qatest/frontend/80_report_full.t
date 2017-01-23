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
    'page' => 'workflow!index!wf_type!report_full',
});
is($result->{main}->[0]->{content}->{fields}->[2]->{name}, 'wf_token');

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'report_config' => '',
    'valid_at' => time(),
});

is ($result->{status}->{level}, 'success');

is($result->{main}->[0]->{content}->{data}->[2]->{format}, 'extlink');

my $link = $result->{main}->[0]->{content}->{data}->[2]->{value}->{page};
like($link, "/fetch/");

my ($noop, $page) = split /=/, $link, 2;

$result = $client->mock_request({
    'page' => $page
});

like( $result, "/^Full Certificate Report, Realm ca-one/", 'Report header ok' );


#!/usr/bin/perl

use lib qw(../../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use JSON;
use MockSC;
use Log::Log4perl qw(:easy);

use Test::More tests => 9;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::SC' );
}

require_ok( 'OpenXPKI::Client::SC' );

#Log::Log4perl->easy_init($DEBUG);

my $client = new MockSC();

my $result = $client->mock_request( 'utilities', 'get_server_status', {} );

is($result->{"get_server_status"}, "Server OK", 'Status'); 
like( $result->{"loadavg"}, qr/^((\d+\.\d+)\s){3}/, 'Load');
like( $result->{"active_processes"}, qr/^(\d+)/, 'Proc Count');
is($result->{"error"}, undef,'No errors');

# check for a card status
#read_config "../scv4/5x_personalize.cfg" => my %config;

$result = $client->mock_request( 'utilities', 'get_card_status', { cardID => '12345678', cardtype => 'Gemalto .NET', ChipSerial => 'chip0815' } );

is($result->{'id_cardID'}, 'gem2_12345678', 'Card Id');
like($result->{'msg'}->{'PARAMS'}->{'OVERALL_STATUS'}, qr/(red|amber|green)/, 'Status word');

$result = $client->mock_request( 'utilities', 'server_log', { level => 'info', message => 'Test Message' } );
is($result->{"error"}, undef,'No errors');

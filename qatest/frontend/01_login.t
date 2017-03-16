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

use Test::More tests => 4;

package main;


my $client = TestCGI->new();

my $result = $client->mock_request({});

$client->update_rtoken();

is($result->{goto}, 'login');

$result = $client->mock_request({
    page => 'login'
});

is($result->{page}->{label}, 'Please log in');
is($result->{main}->[0]->{action}, 'login!stack');

$result = $client->mock_request({
    'action' => 'login!stack',
    'auth_stack' => "Testing",
});

$result = $client->mock_request({
    'action' => 'login!password',
    'username' => 'raop',
    'password' => 'openxpki'
});

is($result->{goto}, 'welcome', 'Logged in');


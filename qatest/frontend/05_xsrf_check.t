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

use Test::More tests => 9;

package main;

my $client = TestCGI->new();

my $result = $client->mock_request({});

is($result->{goto}, 'login');

$result = $client->mock_request({
    page => 'login'
});

is($result->{page}->{label}, 'Please log in');
is($result->{main}->[0]->{action}, 'login!stack');

# update token in session but delete it (login is allowed without session)
$client->update_rtoken();
$client->rtoken('');

$result = $client->mock_request({
    'action' => 'login!stack',
    'auth_stack' => "Testing",
});

# no request token was given, so action is not accepted
is($result->{goto}, 'login');

# load rtoken and try again
$client->update_rtoken();
$result = $client->mock_request({
    'action' => 'login!stack',
    'auth_stack' => "Testing",
});

is($result->{main}->[0]->{action}, 'login!password');

$result = $client->mock_request({
    'action' => 'login!password',
    'username' => 'raop',
    'password' => 'openxpki'
});

is($result->{goto}, 'welcome');


$result = $client->mock_request({
    'page' => 'workflow!index!wf_type!report_full',
});

$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'report_config' => '',
    'valid_at' => time(),
});

# token is wrong now, so this must not work
like($result->{status}->{message}, "/security token was invalid/");

# try with empty token
$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'report_config' => '',
    'valid_at' => time(),
    '_rtoken' => ''
});

# empty token must not work
like($result->{status}->{message}, "/security token was invalid/");

# refresh the token
my $rtoken = $client->update_rtoken();
$result = $client->mock_request({
    'action' => 'workflow!index',
    'wf_token' => undef,
    'report_config' => '',
    'valid_at' => time(),
    '_rtoken' => $rtoken
});

is($result->{page}->{label}, 'Report Result / Certificate Detail Report ');


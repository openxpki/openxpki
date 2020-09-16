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

use Test::More tests => 8;

package main;


my $client = TestCGI->new();

my $result = $client->mock_request({});

$client->update_rtoken();

is($result->{goto}, 'login');

$result = $client->mock_request({
    page => 'login'
});

is($result->{page}->{label}, 'I18N_OPENXPKI_UI_LOGIN_PLEASE_LOG_IN');
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

like($result->{goto}, "/(redirect\!)?welcome/", 'Logged in - Welcome');

$result = $client->mock_request({
    'page' => 'logout',
});

like($result->{goto}, "/login!logout/", 'Logout Page');

$result = $client->mock_request({
    'page' => 'information!issuer',
});

like($result->{goto}, "/login/", 'Login requested');

$result = $client->mock_request({
    'action' => 'login!stack',
    'auth_stack' => "Testing",
});

$result = $client->mock_request({
    'action' => 'login!password',
    'username' => 'raop',
    'password' => 'openxpki'
});

like($result->{goto}, "/(redirect\!)?welcome/", 'Logged in - Welcome');

$result = $client->mock_request({
    'page' => 'welcome',
});

like($result->{goto}, "/information!issuer/", 'Redirect to requested page');


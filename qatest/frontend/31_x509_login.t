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

use Test::More tests => 5;

package main;

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ssl_opts = {
    verify_hostname => 0,
    SSL_key_file => 'tmp/pkiclient.key',
    SSL_cert_file => 'tmp/pkiclient.crt',
    SSL_ca_file => 'tmp/chain.pem',
};
my $client = TestCGI->new( ssl_opts => $ssl_opts );

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
    'auth_stack' => "Certificate",
});

like($result->{goto}, "/(redirect\!)?welcome/", 'Logged in - Welcome');

$result = $client->mock_request({
    'page' => 'logout',
});

like($result->{goto}, "/login!logout/", 'Logout Page');


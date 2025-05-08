#!/usr/bin/perl

use FindBin qw( $Bin );
use lib "$Bin/../../lib";

use strict;
use warnings;
use CGI::Session;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use MockUI;
use OpenXPKI::Defaults;

#Log::Log4perl->easy_init($DEBUG);
Log::Log4perl->easy_init($ERROR);

use Test::More tests => 7;

package main;

BEGIN {
    use_ok( 'OpenXPKI::Client::Service::WebUI' );
}

require_ok( 'OpenXPKI::Client::Service::WebUI' );

my $log = Log::Log4perl->get_logger();

my $session = CGI::Session->new(undef, undef, {Directory=>'/tmp'});
my $session_id = $session->id;
ok ($session->id, 'Session id ok');


my $result;
my $client = MockUI->new({
    session => $session,
    logger => $log,
    config => { socket => $OpenXPKI::Defaults::SERVER_SOCKET }
});

$client->update_rtoken();

$result = $client->mock_request({});
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

is($result->{goto}, 'redirect!welcome', 'Logged in');

use strict;
use warnings;
use English;
use lib 't/20_webserver/lib';

use OpenXPKI::Client::HTML::Mason::Test::Server;
use WWW::Mechanize;
use URI::Escape;

use Test::More;
plan tests => 12;

my $TEST_PORT = 8099;
if ($ENV{MASON_TEST_PORT}) {
    # just in case someone wants to overwrite the test webserver port
    # for some reason
    $TEST_PORT = $ENV{MASON_TEST_PORT};
}

diag("Start page and login");

my $server = OpenXPKI::Client::HTML::Mason::Test::Server->new($TEST_PORT);
$server->started_ok('Webserver start');
my $mech = WWW::Mechanize->new();

# login as anonymous
my $index_page = $mech->get("http://127.0.0.1:$TEST_PORT/")->content();
unlike($index_page, qr/I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED/, 'No connection failed error on start page') or diag "Index: $index_page";
like($index_page, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_GET_AUTHENTICATION_STACK_TITLE/, 'Correct title');

$mech->form_name('OpenXPKI');
$mech->field('auth_stack', 'Anonymous');
$mech->click('submit');
is($mech->response->code(), '200', 'HTTP 200 OK received');
like($mech->response->content, qr/meta http-equiv="refresh"/, 'Redirect page received');

my ($session_id) = ($mech->response->content =~ m{__session_id=([0-9a-f]+)}xms);
if ($ENV{DEBUG}) {
    diag "Session ID: $session_id";
}

# go to redirect page
$mech->get("http://127.0.0.1:$TEST_PORT/service/index.html?__session_id=$session_id&__role=");
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_TITLE/, 'Correct title');

ok($mech->follow_link(text => 'I18N_OPENXPKI_HTML_MENU_DOWNLOAD', n => '1'), 'Followed link');
ok($mech->follow_link(text => 'I18N_OPENXPKI_HTML_MENU_CA_CERTIFICATES'), 'Followed link');

like($mech->response->content, qr/Testing CA/, 'Testing CA is listed'), 
like($mech->response->content, qr/I18N_OPENXPKI_CA_STATUS_USABLE/, 'At least one CA is usable'), 

ok($mech->follow_link(text => 'Testing CA', n=> '1'), 'Followed link');
like($mech->response->content, qr/CN=Testing CA,OU=Testing CA,O=OpenXPKI/, 'CA certificate info shows subject'), 

# TODO - issue a CRL later on and show the list then ...
#ok($mech->follow_link(text => 'I18N_OPENXPKI_HTML_MENU_LIST_CRL', n=> '1'), 'Followed link');
#like($mech->response->content, qr/CN=Testing CA,OU=Testing CA,O=OpenXPKI/, 'CRL listed for testdummyca1'), 
# TODO - policy tests ... - !?

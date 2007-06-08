use strict;
use warnings;
use English;
use lib 't/20_webserver/lib';

use OpenXPKI::Client::HTML::Mason::Test::Server;
use WWW::Mechanize;

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
# TODO - actually follow redirect chain, we're cheating a bit here, the
# first redirect seems to be
# http://127.0.0.1:$TEST_PORT/authentication/dhandler?;__session_id=$session_id&__role=&no_menu=

# go to redirect page
$mech->get("http://127.0.0.1:8099/service/index.html?__session_id=$session_id&__role=");
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_TITLE/, 'Correct title');

foreach my $menu_item (qw(
    I18N_OPENXPKI_HTML_MENU_CA_INFO
    I18N_OPENXPKI_HTML_MENU_CREATE_CSR
    I18N_OPENXPKI_HTML_MENU_CREATE_CRR
    I18N_OPENXPKI_HTML_MENU_SEARCH_CERT
    I18N_OPENXPKI_HTML_MENU_LANGUAGE
    I18N_OPENXPKI_HTML_MENU_LOGOUT
    )) {
    like($mech->response->content, qr/$menu_item/, 
        "Menu item $menu_item is present on page");
}
# TODO - check for menu items that should not appear on anonymous page


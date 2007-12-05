use strict;
use warnings;
use English;
use lib 't/20_webserver/lib';

use OpenXPKI::Client::HTML::Mason::Test::Server;
use WWW::Mechanize;
use URI::Escape;

use Test::More;
plan tests => 60;

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

foreach my $menu_item (qw(
    I18N_OPENXPKI_HTML_MENU_HOME
    I18N_OPENXPKI_HTML_MENU_REQUEST
    I18N_OPENXPKI_HTML_MENU_DOWNLOAD
    I18N_OPENXPKI_HTML_MENU_SEARCH
    I18N_OPENXPKI_HTML_MENU_LOGOUT
    )) {
    like($mech->response->content, qr/$menu_item/, 
        "Menu item $menu_item is present on page");
}
# TODO - check for menu items that should not appear on anonymous page

ok($mech->follow_link(text => 'I18N_OPENXPKI_HTML_MENU_LOGOUT', n => '1'), 'Followed link');
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_LOGOUT_SUCCESS_TITLE/, 'Logout successfull');


# login using external dynamic stack
my %expected_menus = (
    'RA Operator' => [
    qw(
        I18N_OPENXPKI_HTML_MENU_TASKS
        I18N_OPENXPKI_HTML_MENU_REQUEST
        I18N_OPENXPKI_HTML_MENU_DOWNLOAD
        I18N_OPENXPKI_HTML_MENU_APPROVAL
        I18N_OPENXPKI_HTML_MENU_SEARCH
        I18N_OPENXPKI_HTML_MENU_LOGOUT
    )
    ],
    'User' => [ 
    qw(
        I18N_OPENXPKI_HTML_MENU_HOME
        I18N_OPENXPKI_HTML_MENU_REQUEST
        I18N_OPENXPKI_HTML_MENU_DOWNLOAD
        I18N_OPENXPKI_HTML_MENU_SEARCH
        I18N_OPENXPKI_HTML_MENU_LOGOUT
    )
    ],
    'CA Operator' => [
    qw(
        I18N_OPENXPKI_HTML_MENU_TASKS
        I18N_OPENXPKI_HTML_MENU_REQUEST
        I18N_OPENXPKI_HTML_MENU_DOWNLOAD
        I18N_OPENXPKI_HTML_MENU_APPROVAL
        I18N_OPENXPKI_HTML_MENU_SEARCH
        I18N_OPENXPKI_HTML_MENU_LOGOUT
    )
    ],
);

my $expected_intro_title = {
    'User' => qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_TITLE/,
    'CA Operator' => qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_CAOP_TITLE/,
    'RA Operator' => qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_RAOP_TITLE/,
};

foreach my $role (keys %expected_menus) {
    diag "Login as external dynamic ($role) ...";
    my $index_page = $mech->get("http://127.0.0.1:$TEST_PORT/")->content();
    unlike($index_page, qr/I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED/, 'No connection failed error on start page') or diag "Index: $index_page";
    like($index_page, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_GET_AUTHENTICATION_STACK_TITLE/, 'Correct title');

    $mech->form_name('OpenXPKI');
    $mech->field('auth_stack', 'External Dynamic');
    $mech->click('submit');

    like($mech->response->content, qr/I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_EXTERNAL/, 'Correct stack');
    $mech->form_name('OpenXPKI');
    $mech->field('login', 'test');
    $mech->field('passwd', $role);
    $mech->click('submit');

    is($mech->response->code(), '200', 'HTTP 200 OK received');
    like($mech->response->content, qr/meta http-equiv="refresh"/, 'Redirect page received');

    my ($session_id) = ($mech->response->content =~ m{__session_id=([0-9a-f]+)}xms);
    if ($ENV{DEBUG}) {
        diag "Session ID: $session_id";
    }

    # go to redirect page
    $mech->get("http://127.0.0.1:$TEST_PORT/service/index.html?__session_id=$session_id&__role=" . uri_escape($role));
    like($mech->response->content, $expected_intro_title->{$role}, 'Correct title');

    foreach my $menu_item (@{ $expected_menus{$role} }) {
        like($mech->response->content, qr/$menu_item/, 
            "Menu item $menu_item is present on page");
    }
    # TODO - check for menu items that should not appear

    ok($mech->follow_link(text => 'I18N_OPENXPKI_HTML_MENU_LOGOUT', n => '1'), 'Followed link');
    like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_LOGOUT_SUCCESS_TITLE/, 'Logout successfull');
}


# login using external static (RA Operator)
$index_page = $mech->get("http://127.0.0.1:$TEST_PORT/")->content();
unlike($index_page, qr/I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED/, 'No connection failed error on start page') or diag "Index: $index_page";
like($index_page, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_GET_AUTHENTICATION_STACK_TITLE/, 'Correct title');

$mech->form_name('OpenXPKI');
$mech->field('auth_stack', 'External Static');
$mech->click('submit');

like($mech->response->content, qr/I18N_OPENXPKI_CONFIG_AUTH_HANDLER_DESCRIPTION_EXTERNAL/, 'Correct stack');
$mech->form_name('OpenXPKI');
$mech->field('login', 'test');
$mech->field('passwd', 'test');
$mech->click('submit');

is($mech->response->code(), '200', 'HTTP 200 OK received');
like($mech->response->content, qr/meta http-equiv="refresh"/, 'Redirect page received');

($session_id) = ($mech->response->content =~ m{__session_id=([0-9a-f]+)}xms);
if ($ENV{DEBUG}) {
    diag "Session ID: $session_id";
}

# go to redirect page
$mech->get("http://127.0.0.1:$TEST_PORT/service/index.html?__session_id=$session_id&__role=RA%20Operator");
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_RAOP_TITLE/, 'Correct title');


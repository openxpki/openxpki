use strict;
use warnings;
use English;
use lib 't/20_webserver/lib';

use OpenXPKI::Client::HTML::Mason::Test::Server;
use WWW::Mechanize;
use URI::Escape;
use Data::Dumper;

use Test::More;
plan tests => 38;

my $TEST_PORT = 8099;
if ($ENV{MASON_TEST_PORT}) {
    # just in case someone wants to overwrite the test webserver port
    # for some reason
    $TEST_PORT = $ENV{MASON_TEST_PORT};
}

diag("CSR Approval and certificate issuance");

my $server = OpenXPKI::Client::HTML::Mason::Test::Server->new($TEST_PORT);
$server->started_ok('Webserver start');
my $mech = WWW::Mechanize->new();

# login as anonymous
my $index_page = $mech->get("http://127.0.0.1:$TEST_PORT/")->content();
unlike($index_page, qr/I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED/, 'No connection failed error on start page') or diag "Index: $index_page";
like($index_page, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_GET_AUTHENTICATION_STACK_TITLE/, 'Correct title');

$mech->form_name('OpenXPKI');
$mech->field('auth_stack', 'External Dynamic');
$mech->click('submit');

$mech->form_name('OpenXPKI');
$mech->field('login', 'raop');
$mech->field('passwd', 'RA Operator');
$mech->click('submit');

like($mech->response->content, qr/meta http-equiv="refresh"/, 'Redirect page received');

my ($session_id) = ($mech->response->content =~ m{__session_id=([0-9a-f]+)}xms);
if ($ENV{DEBUG}) {
    diag "Session ID: $session_id";
}

# go to redirect page
$mech->get("http://127.0.0.1:$TEST_PORT/service/index.html?__session_id=$session_id&__role=RA%20Operator");
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_INTRO_RAOP_TITLE/, 'Correct title');

like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_WORKFLOW_SHOW_PENDING_REQUESTS_TITLE/, 'Show pending requests page');
like($mech->response->content, qr/example1.example.com/, 'example1 present');
like($mech->response->content, qr/example2.example.com/, 'example2 present');
like($mech->response->content, qr/example3.example.com/, 'example3 present');
like($mech->response->content, qr/example4.example.com/, 'example4 present');

ok($mech->follow_link(text => '1279', n => '1'), 'Followed link');
like($mech->response->content, qr/I18N_OPENXPKI_WF_ACTION_APPROVE_CSR/, 'Approve button present');

like($mech->response->content, qr/I18N_OPENXPKI_WF_ACTION_REJECT_CSR/, 'Reject button present');
like($mech->response->content, qr/I18N_OPENXPKI_HTML_MASON_CHANGE/, 'Change button(s) present');
like($mech->response->content, qr/comment/, 'Comment present');

ok($mech->follow_link(text => 'CN=example1.example.com:1234, DC=Test Deployment, DC=OpenXPKI, DC=org', n => '1'), 'Followed link') or diag $mech->response->content;
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_API_CERT_LIST_TITLE/, 'Certificate search result page');
unlike($mech->response->content, qr/example1.example.com:1234/, 'No prior certificate with same DN present');
$mech->back();

#$mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/activity/approve_csr.html?id=1279;type=I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST;__session_id=$session_id&__role=RA%20Operator");
#$mech->form_name('OpenXPKI');
#$mech->field('id', '1279');
#$mech->field('filled', '1');
#$mech->field('signature', '');
#$mech->field('text', '');
#$mech->field('type', 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST');
#$mech->click('nosign');

#like($mech->response->content, qr/raop\&amp;rarr;RA Operator/, 'Approval present');

$mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/activity/cancel_csr_approval.html?id=1279;type=I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST;__session_id=$session_id&__role=RA%20Operator");
$mech->form_name('OpenXPKI');
$mech->click('__submit');
unlike($mech->response->content, qr/raop\&amp;rarr;RA Operator/, 'No approval present after cancelling');

$mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/activity/reject_csr.html?id=1279;type=I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST;__session_id=$session_id&__role=RA%20Operator");
$mech->form_name('OpenXPKI');
$mech->click('__submit');
like($mech->response->content, qr/FAILURE/, 'FAILURE after rejection');

$mech->get("http://127.0.0.1:$TEST_PORT/service/index.html?__session_id=$session_id&__role=RA%20Operator");
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_WORKFLOW_SHOW_PENDING_REQUESTS_TITLE/, 'Show pending requests page');
unlike($mech->response->content, qr/example1.example.com/, 'example1 no longer present');
like($mech->response->content, qr/example2.example.com/, 'example2 present');
like($mech->response->content, qr/example3.example.com/, 'example3 present');
like($mech->response->content, qr/example4.example.com/, 'example4 present');

ok($mech->follow_link(text => '2047', n => '1'), 'Followed link');

like($mech->response->content, qr/I18N_OPENXPKI_WF_ACTION_APPROVE_CSR/, 'Approve button present');
like($mech->response->content, qr/I18N_OPENXPKI_WF_ACTION_REJECT_CSR/, 'Reject button present');
like($mech->response->content, qr/I18N_OPENXPKI_HTML_MASON_CHANGE/, 'Change button(s) present');
like($mech->response->content, qr/comment/, 'Comment present');

ok($mech->follow_link(text => 'CN=example2.example.com:1234, DC=Test Deployment, DC=OpenXPKI, DC=org', n => '1'), 'Followed link');
unlike($mech->response->content, qr/example2.example.com:1234/, 'No prior certificate with same DN present');
$mech->back();

ok($mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/activity/change_notbefore.html?__session_id=$session_id&__role=RA%20Operator&id=2047&type=I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST"), 'Followed notbefore link') or diag $mech->response->content;
like($mech->response->content, qr/I18N_OPENXPKI_CLIENT_HTML_MASON_ACTIVITY_CHANGE_NOTBEFORE_TITLE/, 'Change notbefore title present') or diag $mech->response->content;
$mech->form_name('OpenXPKI');
$mech->field('hour', '23');
$mech->field('seconds', '59');
$mech->field('minute', '42');
$mech->field('month', '12');
$mech->field('day', '13');
$mech->field('year', '2000');
$mech->click('__submit');
like($mech->response->content, qr/2000-12-13 23:42:59/, 'notbefore time present on show_instance page');

$mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/activity/approve_csr.html?id=2047;type=I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST;__session_id=$session_id&__role=RA%20Operator");
$mech->form_name('OpenXPKI');
$mech->field('id', '2047');
$mech->field('filled', '1');
$mech->field('signature', '');
$mech->field('text', '');
$mech->field('type', 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST');
$mech->click('nosign');

# the approval can no longer be seen because of the workflow ACLs ...
#like($mech->response->content, qr/raop\&amp;rarr;RA Operator/, 'Approval present');

#$mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/activity/persist_csr.html?id=2047;type=I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST;__session_id=$session_id&__role=RA%20Operator");

ok($mech->response->content =~ qr/WAITING_FOR_CHILD/ || $mech->response->content =~ qr/SUCCESS/, 'WF in state WAITING_FOR_CHILD or SUCCESS after persist') || diag $mech->response->content;

# cert issuance workflow
$mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/search_instances.html?__session_id=$session_id&__role=RA%20Operator&type=I18N_OPENXPKI_WF_TYPE_CERTIFICATE_ISSUANCE&context_key=&context_value=&__submit=OK");
my $i = 0;
while ($i < 60 && $mech->response->content !~ qr/SUCCESS/) {
    $i++;
    if ($ENV{DEBUG}) {
        diag $mech->response->content();
        diag "Sleeping ...";
    }
    sleep 1;
    $mech->get("http://127.0.0.1:$TEST_PORT/service/workflow/show_instance.html?id=5375;__session_id=$session_id&__role=RA%20Operator");
}
like($mech->response->content, qr/SUCCESS/, 'Cert issuance workflow in state success');
like($mech->response->content, qr/-----BEGIN\ CERTIFICATE-----/, 'Certificate present');

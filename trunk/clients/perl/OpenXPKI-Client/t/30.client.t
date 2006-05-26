use Test::More tests => 12;
use English;

use strict;
use warnings;
use Smart::Comments;

use OpenXPKI::Client;

our %config;
require 't/common.pl';

my $debug = $config{debug};

diag("Client library tests");

my $cli = OpenXPKI::Client->new(
    {
	SOCKETFILE => $config{socket_file},
    });

ok(defined $cli);

ok($cli->init_session());

my $session_id;
ok($session_id = $cli->get_session_id());
diag("Got session id $session_id");

ok($cli->get_communication_state() eq 'can_receive');

my $response;

$response = $cli->collect();

ok($response->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK');
ok(exists $response->{AUTHENTICATION_STACKS}->{Anonymous});
ok($response->{AUTHENTICATION_STACKS}->{Anonymous}->{NAME} eq 'Anonymous');

# try to login
$response = $cli->send_receive_service_msg('GET_AUTHENTICATION_STACK',
					   {
					       AUTHENTICATION_STACK => 'Anonymous',
					   });
ok($response->{SERVICE_MSG} eq 'SERVICE_READY');

# try to operate a simple Server API function
$response = $cli->get_API()->nop();
### $response
ok(ref $response eq 'HASH');
ok($response->{SERVICE_MSG} eq 'COMMAND');
ok($response->{COMMAND} eq 'nop');
ok(ref $response->{PARAMS} eq 'HASH');


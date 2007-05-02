use Test::More tests => 12;
use English;

use strict;
use warnings;
# use Smart::Comments;

use OpenXPKI::Client;
use Data::Dumper;

our %config;
require 't/common.pl';

my $debug = $config{debug};

diag("Client library tests");

my $cli = OpenXPKI::Client->new(
    {
	SOCKETFILE => $config{socket_file},
    });

ok(defined $cli, 'Client object defined');

ok($cli->init_session(), 'Init session');
#BAIL_OUT("exiting...");

my $session_id;
ok($session_id = $cli->get_session_id(), 'get_session_id()');
diag("Got session id $session_id");

ok($cli->get_communication_state() eq 'can_send', 'status: can_send');

my $response = $cli->send_receive_service_msg('PING');

ok($response->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK', 'Response is GET_AUTHENTICATION_STACK') or diag Dumper $response;
ok(exists $response->{PARAMS}->{AUTHENTICATION_STACKS}->{Anonymous}, 'Response contains anonymous auth stack') or diag Dumper $response;

### $response
# try to login
$response = $cli->send_receive_service_msg('GET_AUTHENTICATION_STACK',
					   {
					       AUTHENTICATION_STACK => 'Anonymous',
					   });
is($response->{SERVICE_MSG}, 'SERVICE_READY', 'Anonymous login') or diag Dumper $response;
### $response

# try to operate a simple Server API function
$response = $cli->get_API()->nop();
### $response

is(ref $response, 'HASH', 'NOP response is a hash') or diag Dumper $response;
is($response->{SERVICE_MSG}, 'COMMAND', 'NOP SERVICE_MSG is COMMAND') or diag Dumper $response;
is($response->{COMMAND}, 'nop', 'NOP COMMAND is nop') or diag Dumper $response;
ok(exists $response->{PARAMS}, 'PARAMS reply exists') or diag Dumper $response;
ok(! defined $response->{PARAMS}, 'PARAMS reply is undef') or diag Dumper $response;


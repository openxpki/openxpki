use Test::More tests => 12;
use English;

use strict;
use warnings;

use Smart::Comments;

our %config;
require 't/common.pl';

diag("CLI client tests");

my $cli = "./bin/openxpki --socketfile $config{socket_file}";

my $session_id = `$cli showsession`;
chomp $session_id;

ok($session_id =~ m{ \A [ \d a-f ]{20} \z }xms);
diag("Got session id $session_id");

my $res = `$cli --session $session_id nop`;

### $res


__END__

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


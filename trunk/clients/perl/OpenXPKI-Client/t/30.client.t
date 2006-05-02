use Test::More tests => 3;
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



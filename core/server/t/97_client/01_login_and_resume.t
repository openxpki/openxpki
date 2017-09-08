package main;
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Test::Server;
use OpenXPKI::Test::Client;


plan tests => 12;


#
# Setup test env
#
my $oxitest = OpenXPKI::Test->new->setup_env;

my $server = OpenXPKI::Test::Server->new(oxitest => $oxitest);
$server->init_tasks( ['crypto_layer'] );
$server->start;

my $tester = OpenXPKI::Test::Client->new(oxitest => $oxitest);
$tester->start;

#
# Tests
#

my $realm = $oxitest->get_default_realm;
my $resp;

$tester->init_session;

my $session_id = $tester->client->get_session_id;

$tester->send_ok('GET_PKI_REALM', { PKI_REALM => $realm });
$tester->is_next_step("GET_AUTHENTICATION_STACK");

$tester->send_ok('GET_AUTHENTICATION_STACK', { AUTHENTICATION_STACK => "Test" });
$tester->is_next_step("GET_PASSWD_LOGIN");

$tester->send_ok('GET_PASSWD_LOGIN', { LOGIN => "caop", PASSWD => $oxitest->config_writer->password });
$tester->is_next_step("SERVICE_READY");

$tester->send_ok('COMMAND', { COMMAND => "get_session_info" });
is $tester->response->{PARAMS}->{name}, "caop", "session info contains user name";

$tester->client->close_connection;

my $tester2 = OpenXPKI::Test::Client->new(oxitest => $oxitest);
$tester2->start;

$tester2->init_session({ SESSION_ID => $session_id });

$server->stop or diag "Could not shutdown test server";

1;

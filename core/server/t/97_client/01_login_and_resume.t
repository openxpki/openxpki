package main;
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use IPC::SysV qw(IPC_PRIVATE IPC_CREAT IPC_EXCL S_IRWXU IPC_NOWAIT);
use IPC::Semaphore;

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;
use OpenXPKI::Test::Server;


plan tests => 15;


#
# Setup test env
#
my $oxitest = OpenXPKI::Test->new();
$oxitest->setup_env;

my $server = OpenXPKI::Test::Server->new(oxitest => $oxitest);
$server->init_tasks( ['crypto_layer'] );
$server->start;

#
# Tests
#
sub is_next_step {
    my ($hash, $msg) = @_;
    ok (
        ($hash and exists $hash->{SERVICE_MSG} and $hash->{SERVICE_MSG} eq $msg),
        "<< server expects $msg"
    ) or diag explain $hash;
}

sub send_ok {
    my ($client, $msg, $args) = @_;
    my $resp;
    lives_and {
        $resp = $client->send_receive_service_msg($msg, $args);
        if (my $err = get_error($resp)) {
            diag $err;
            fail;
        }
        else {
            pass;
        }
    } ">> send $msg";

    return $resp;
}

sub get_error {
    my ($resp) = @_;
    if ($resp and exists $resp->{SERVICE_MSG} and $resp->{SERVICE_MSG} eq 'ERROR') {
        return $resp->{LIST}->[0]->{LABEL} || 'Unknown error';
    }
    return;
}

my $realm = $oxitest->get_default_realm;
my $resp;

use_ok "OpenXPKI::Client";

my $client;
lives_ok {
    $client = OpenXPKI::Client->new({
        TIMEOUT => 5,
        SOCKETFILE => $oxitest->get_config("system.server.socket_file"),
    });
} "client instance";

lives_ok {
    $resp = $client->init_session();
} "initialize client session";
is_next_step $resp, "GET_PKI_REALM";

my $session_id = $client->get_session_id;

$resp = send_ok $client, 'GET_PKI_REALM', { PKI_REALM => $realm };
is_next_step $resp, "GET_AUTHENTICATION_STACK";

$resp = send_ok $client, 'GET_AUTHENTICATION_STACK', { AUTHENTICATION_STACK => "Test" };
is_next_step $resp, "GET_PASSWD_LOGIN";

$resp = send_ok $client, 'GET_PASSWD_LOGIN', { LOGIN => "caop", PASSWD => $oxitest->config_writer->password };
is_next_step $resp, "SERVICE_READY";

$resp = send_ok $client, 'COMMAND', { COMMAND => "get_session_info" };
is $resp->{PARAMS}->{name}, "caop", "session info contains user name";

$client->close_connection;

lives_ok {
    $client = OpenXPKI::Client->new({
        TIMEOUT => 5,
        SOCKETFILE => $oxitest->get_config("system.server.socket_file"),
    });
} "client instance no. 2";

lives_ok {
    $resp = $client->init_session({ SESSION_ID => $session_id });
} "initialize client session no. 2 with previous session id";

is_next_step $resp, "SERVICE_READY";

$server->stop or diag "Could not shutdown test server";

1;

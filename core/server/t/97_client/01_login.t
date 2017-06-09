package main;
use strict;
use warnings;

# Core modules
use English;
use FindBin qw( $Bin );
use File::Path qw( remove_tree );
use File::Temp qw( tempdir );
use Proc::Daemon;
use IPC::SysV qw(IPC_PRIVATE IPC_CREAT IPC_EXCL S_IRWXU IPC_NOWAIT);
use IPC::Semaphore;

# CPAN modules
use Test::More;
use Test::Exception;
use Test::Deep;

# Project modules
use lib "$Bin/../lib";
use OpenXPKI::Test;


plan tests => 3;


#
# Setup test env
#
my $dir = tempdir();

my $oxitest = OpenXPKI::Test->new(testenv_root => $dir);
$oxitest->setup_env;

# create semaphore set with 1 member
my $sem = IPC::Semaphore->new(IPC_PRIVATE, 1, S_IRWXU | IPC_CREAT | IPC_EXCL)
    or die "Could not create semaphore: $!";
# lock semaphore (set semaphore #0 to 1)
$sem->setval(0,1)
    or die "Could not set semaphore: $!";

# fork server process
note "Starting test server...";
my $daemon = Proc::Daemon->new(
    work_dir => $dir,
    # dont_close_fh => [ 'STDOUT', 'STDERR' ],
);
my $child_pid = $daemon->Init;


unless ( $child_pid ) {
    # code executed only by the child ...

    # init_server() must be called after Proc::Daemon->Init() because the latter
    # closes all file handles which would cause problems with Log4perl
    $oxitest->init_server;
    use OpenXPKI::Server;
    my $server = OpenXPKI::Server->new(
        'SILENT' => $ENV{VERBOSE} ? 0 : 1,
        'TYPE'   => 'Simple',
    );
    $server->__init_user_interfaces;
    $server->__init_net_server;

    # unlock semaphore
    $sem->op(0, -1, IPC_NOWAIT);

    $server->run(%{$server->{PARAMS}}); # from Net::Server::MultiType
    exit;
}

# wait till child process unlocks semaphore
# (# semaphore #0, operation 0)
for (my $tick = 0; $tick < 3 and not $sem->op(0, 0, IPC_NOWAIT); $tick++) {
    sleep 1;
}
if (not $sem->op(0, 0, IPC_NOWAIT)) {
    $daemon->Kill_Daemon($child_pid);
    remove_tree $dir;
    die "Server startup seems to have failed";
}

sleep 1; # give Net::Server->run() a little bit time

#
# Tests
#
use_ok "OpenXPKI::Client";

my $client;
lives_ok {
    $client = OpenXPKI::Client->new({
        TIMEOUT => 5,
        SOCKETFILE => $oxitest->get_config("system.server.socket_file"),
    });
} "OpenXPKI::Client->new";

my $realm = $oxitest->get_default_realm;

lives_ok {
    $client->init_session();
} "initialize client session";

$daemon->Kill_Daemon($child_pid) or diag "Could not kill test server";

remove_tree $dir;

#$msg = $client->send_receive_service_msg( 'GET_PKI_REALM',
#                { PKI_REALM => $realm } );
#            $self->set_msg($msg);
#            if ( $self->error ) {
#                $self->diag(
#                    "Login failed (get pki realm $realm): " . Dumper $msg);
#                return;
#            }
#            $msg = $client->send_receive_service_msg( 'PING', );
#            $self->set_msg($msg);
#            if ( $self->error ) {
#                $self->diag( "Login failed (ping): " . Dumper $msg);
#                return;
#            }
#
#my $stack = $self->get_stack || 'Testing';
#            $msg
#                = $client->send_receive_service_msg(
#                'GET_AUTHENTICATION_STACK',
#                { 'AUTHENTICATION_STACK' => $stack, },
#                );
#            $self->set_msg($msg);
#            if ( $self->error ) {
#                $self->diag(
#                    "Login failed (stack selection): " . Dumper $msg);
#                return;
#            }
#
#            $msg = $client->send_receive_service_msg(
#                'GET_PASSWD_LOGIN',
#                {   'LOGIN'  => $user,
#                    'PASSWD' => $pass,
#                },
#            );
#            $self->set_msg($msg);
#            if ( $self->error ) {
#                $self->diag( "Login failed: " . Dumper $msg);
#                return;
#            }
1;

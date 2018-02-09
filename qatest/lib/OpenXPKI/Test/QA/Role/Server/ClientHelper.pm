package OpenXPKI::Test::QA::Role::Server::ClientHelper;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::QA::Role::Server::ClientHelper - Helper functions to test
OpenXPKI client talking to a running (test) server

=head1 SYNOPSIS

This class is not meant to be instantiated directly but via
L<OpenXPKI::Test::QA::Role::Server/new_client_tester>, ie:

    my $oxitest = OpenXPKI::Test->new(with => [ qw( SampleConfig Server ) ]);
    my $client = $oxitest->new_client_tester;

To automatically connect and start a new session just call L</login>:

    $client = $oxitest->login("caop");

This is equivalent to:

    $client = $oxitest->connect;
    $client = $oxitest->init_session;
    $client = $oxitest->login("caop");

Alternatively to continue an existing session:

    $client = $oxitest->init_session({ SESSION_ID => $session_id });

=cut

# Core modules
use Test::More;
use Test::Exception;

# CPAN modules

# Project modules
use OpenXPKI::Client;

=head1 METHODS

=head2 new

Constructor.

B<Parameters> (these are Moose attributes and can be accessed as such)

=over

=item * I<socket_file> (Str) - path to the Unix communication socket between
server and client

=cut
has socket_file => (
    is => 'rw',
    does => 'Str',
    required => 1,
);

=item * I<default_realm> (Str) - default PKI realm

=cut
has default_realm => (
    is => 'rw',
    does => 'Str',
    required => 1,
);

=item * I<password> (Str) - password for all test users (for login)

=cut
has password => (
    is => 'rw',
    does => 'Str',
    required => 1,
);

=back

=head1 METHODS

=head2 client

Returns a reference to the L<OpenXPKI::Client> object internally used.

=cut
has client => (
    is => 'rw',
    isa => 'OpenXPKI::Client',
    init_arg => undef,
    predicate => 'is_connected',
);

=head2 response

Returns the server response of the last command (I<Hashref>).

=cut
has response => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
);

=head2 connect

Connects to the OpenXPKI test server via socket.

=cut
sub connect {
    my $self = shift;

    return if $self->is_connected;

    lives_ok {
        # instantiating the client means starting it as all initialization is
        # done in the constructor
        $self->client(
            OpenXPKI::Client->new({
                TIMEOUT => 5,
                SOCKETFILE => $self->socket_file,
            })
        );
    } "create client instance" or BAIL_OUT "Could not create client instance";
}

=head2 init_session

Initializes a new or continues an existing client session.

Automatically calls L</connect> if neccessary.

B<Positional parameters>

=over

=item * I<$args> (HashRef) - arguments passed to L<OpenXPKI::Client/init_session>

=back

=cut
sub init_session {
    my ($self, $args) = @_;

    $self->connect;

    lives_and {
        $self->response($self->client->init_session($args));
        # if we sent an active session...
        if ($args and $args->{'SESSION_ID'}) {
            $self->is_next_step("SERVICE_READY");
        }
        else {
            # server wants the PKI realm only if there is more than one available
            ok ($self->is_service_msg("GET_PKI_REALM") or $self->is_service_msg("GET_AUTHENTICATION_STACK")),
             "<< server expects GET_PKI_REALM or GET_AUTHENTICATION_STACK"
             or diag explain $self->response;
        }
    } "initialize client session";
}

=head2 login

Asks the server to log in the given user with the authentication stack I<Test>.

Automatically calls L</init_session> if neccessary.

B<Positional parameters>

=over

=item * I<$user> (Str) - user name to log in (password is taken from C<$self-E<gt>password>)

=back

=cut
sub login {
    my ($self, $user) = @_;

    $self->init_session unless ($self->is_connected and $self->client->get_session_id);

    subtest "client login" => sub {
        # requested by server only if there is more than one realm in the config
        if ($self->is_service_msg("GET_PKI_REALM")) {
            plan tests => 6;
            $self->send_ok('GET_PKI_REALM', { PKI_REALM => $self->default_realm });
            $self->is_next_step("GET_AUTHENTICATION_STACK");
        }
        else {
            plan tests => 4;
        }

        $self->send_ok('GET_AUTHENTICATION_STACK', { AUTHENTICATION_STACK => "Test" });
        $self->is_next_step("GET_PASSWD_LOGIN");

        $self->send_ok('GET_PASSWD_LOGIN', { LOGIN => $user, PASSWD => $self->password });
        $self->is_next_step("SERVICE_READY");
    }
}

=head2 is_next_step

Tests if the next step as returned by the server matches the given string.

B<Positional parameters>

=over

=item * I<$step> (Str) - login workflow step

=back

=cut
sub is_next_step {
    my ($self, $step) = @_;
    ok $self->is_service_msg($step), "<< server expects $step"
        or diag("server response: ".explain($self->response));
}

=head2 send_ok

Sends the given message to the server using
L<OpenXPKI::Client/send_receive_service_msg> and wraps that in a test.

Returns the server response (I<HashRef>).

B<Positional parameters>

=over

=item * I<$msg> (Str) - message to send to the server

=item * I<$args> (HashRef) - additional arguments

=back

=cut
sub send_ok {
    my ($self, $msg, $args) = @_;

    die "Please call 'connect', 'init_session' or at least 'login' before sending commands"
     unless $self->is_connected;

    lives_and {
        $self->response($self->client->send_receive_service_msg($msg, $args));
        if (my $err = $self->get_error) {
            diag "error: $err";
            fail;
        }
        else {
            pass;
        }
    } ">> send $msg".($msg eq "COMMAND" ? ": ".$args->{COMMAND} : "");

    return $self->response->{PARAMS};
}

=head2 send_command_ok

Sends the given command (ie. message "COMMAND") to the server using and wraps
that in a test.

Returns the server response (I<HashRef>).

B<Positional parameters>

=over

=item * I<$command> (Str) - command to send to the server

=item * I<$params> (HashRef) - additional command parameters

=back

=cut
sub send_command_ok {
    my ($self, $command, $params) = @_;
    return $self->send_ok('COMMAND', { COMMAND => $command, PARAMS => $params });
}

=head2 send_command_api2_ok

Sends the given command (ie. message "COMMAND") to the server for execution via
the new API (API2) and wraps that in a test.

Returns the server response (I<HashRef>).

B<Positional parameters>

=over

=item * I<$command> (Str) - command to send to the server

=item * I<$params> (HashRef) - additional command parameters

=back

=cut
sub send_command_api2_ok {
    my ($self, $command, $params) = @_;
    return $self->send_ok('COMMAND', { COMMAND => $command, PARAMS => $params, API2 => 1 });
}

=head2 is_service_msg

Returns TRUE if the last server response equals the given string, FALSE
otherwise.

B<Positional parameters>

=over

=item * I<$msg> (Str) - expected server message

=back

=cut
sub is_service_msg {
    my ($self, $msg) = @_;
    return unless $self->response;
    return unless exists $self->response->{SERVICE_MSG};
    return $self->response->{SERVICE_MSG} eq $msg;
}

=head2 get_error

Returns the last error message from the server or UNDEF if there was none.

=cut
sub get_error {
    my $self = shift;
    if ($self->is_service_msg('ERROR')) {
        return $self->response->{LIST}->[0]->{LABEL} || 'Unknown error';
    }
    return;
}

__PACKAGE__->meta->make_immutable;

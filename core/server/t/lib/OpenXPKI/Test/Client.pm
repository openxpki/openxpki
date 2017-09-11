package OpenXPKI::Test::Client;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::Client - Helper functions to test OpenXPKI client talking to a
running (test) server

=cut

# Core modules
use Test::More;
use Test::Exception;

# CPAN modules

# Project modules
use OpenXPKI::Client;

=head1 DESCRIPTION

=cut

has oxitest => (
    is => 'rw',
    isa => 'OpenXPKI::Test',
    required => 1,
);

has client => (
    is => 'rw',
    isa => 'OpenXPKI::Client',
    init_arg => undef,
);

has response => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => undef,
);

=head1 METHODS

=cut
sub connect {
    my $self = shift;

    my $client;
    lives_ok {
        # instantiating the client means starting it as all initialization is
        # done in the constructor
        $client = OpenXPKI::Client->new({
            TIMEOUT => 5,
            SOCKETFILE => $self->oxitest->get_config("system.server.socket_file"),
        });
    } "create client instance" or BAIL_OUT "Could not create client instance";

    $self->client($client);
}

sub init_session {
    my ($self, $args) = @_;
    lives_and {
        $self->response($self->client->init_session($args));
        $self->is_next_step(($args and $args->{'SESSION_ID'}) ? "SERVICE_READY" : "GET_PKI_REALM");
    } "initialize client session";
}

sub login {
    my ($self, $user) = @_;
    subtest "client login" => sub {
        plan tests => 6;

        $self->send_ok('GET_PKI_REALM', { PKI_REALM => $self->oxitest->get_default_realm });
        $self->is_next_step("GET_AUTHENTICATION_STACK");

        $self->send_ok('GET_AUTHENTICATION_STACK', { AUTHENTICATION_STACK => "Test" });
        $self->is_next_step("GET_PASSWD_LOGIN");

        $self->send_ok('GET_PASSWD_LOGIN', { LOGIN => $user, PASSWD => $self->oxitest->config_writer->password });
        $self->is_next_step("SERVICE_READY");
    }
}

sub is_next_step {
    my ($self, $msg) = @_;
    ok $self->is_service_msg($msg), "<< server expects $msg"
        or diag explain $self->response;
}

sub send_ok {
    my ($self, $msg, $args) = @_;
    lives_and {
        $self->response($self->client->send_receive_service_msg($msg, $args));
        if (my $err = $self->get_error) {
            diag $err;
            fail;
        }
        else {
            pass;
        }
    } ">> send $msg";

    return $self->response->{PARAMS};
}

sub is_service_msg {
    my ($self, $msg) = @_;
    return unless $self->response;
    return unless exists $self->response->{SERVICE_MSG};
    return $self->response->{SERVICE_MSG} eq $msg;
}

sub get_error {
    my $self = shift;
    if ($self->is_service_msg('ERROR')) {
        return $self->response->{LIST}->[0]->{LABEL} || 'Unknown error';
    }
    return;
}

__PACKAGE__->meta->make_immutable;

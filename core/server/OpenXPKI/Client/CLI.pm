package OpenXPKI::Client::CLI;

use Moose;
extends 'OpenXPKI::Client';
with 'OpenXPKI::Role::Logger';

use Crypt::JWT qw(encode_jwt);
use Crypt::PK::ECC;
use Data::Dumper;

use OpenXPKI::DTO::Message::Command;


=head1 NAME

OpenXPKI::Client::CLI

=head1 SYNOPSIS

Provides an object to communicate with the OpenXPKI Backend using
C<OpenXPKI::Service::CLI>.

=cut

has '+socketfile' => (
    default => '/var/openxpki/openxpki.socket',
);

has '+service' => (
    default => 'CLI',
);

has authenticator => (
    is => 'ro',
    isa => 'OpenXPKI::DTO::Authenticator',
    required => 1,
);

=cut
has session_id => (
    is => 'rw',
    isa => 'Str',
    required => 0,
    predicate => 'has_session_id',
);
=cut

sub send_message {

    my $self = shift;
    my $message = shift;

    my %header;
    my $auth = $self->authenticator();
    if ($auth->has_pki_realm()) {
        $header{pki_realm} = $auth->pki_realm();
    }

    $self->log->trace(Dumper $auth);

    my $payload = $message->to_hash();
    $self->log()->trace(Dumper $payload) if ($self->log()->is_trace);

    my $msg;
    if ($auth->has_account_key()) {
        my $pk = $self->authenticator()->account_key();
        $msg = encode_jwt(
            payload => $payload,
            alg => 'ES256',
            key => $pk,
            extra_headers => { kid => $pk->export_key_jwk_thumbprint(), %header },
        );
    } else {
        $msg = encode_jwt(
            payload => $payload,
            alg => 'none',
            allow_none => 1,
            extra_headers => { %header, stack => $auth->stack(), %{$auth->credentials()} },
        );
    }
    $self->log()->debug($msg) if ($self->log()->is_debug);
    return $self->talk($msg);
}


1;
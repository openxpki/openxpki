package OpenXPKI::Client::CLI;
use OpenXPKI -class;

extends 'OpenXPKI::Client';
with 'OpenXPKI::Role::Logger';

use Crypt::JWT qw(encode_jwt);
use Crypt::PK::ECC;

use OpenXPKI::DTO::Message;

=head1 NAME

OpenXPKI::Client::CLI

=head1 SYNOPSIS

Provides an object to communicate with the OpenXPKI Backend using
C<OpenXPKI::Service::CLI>.

=cut

has '+socketfile' => (
    default => '/run/openxpkid/openxpkid.sock',
);

has '+service' => (
    default => 'CLI',
);

has authenticator => (
    is => 'ro',
    isa => 'OpenXPKI::DTO::Authenticator',
    required => 1,
);

=pod

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
    my $res = $self->talk($msg);
    $self->log()->trace(Dumper $res) if ($self->log()->is_trace);
    return OpenXPKI::DTO::Message::from_hash($res);
}


1;
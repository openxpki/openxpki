package OpenXPKI::Client::SCEP;

use Moose;
use warnings;
use strict;
use Carp;
use English;

use OpenXPKI::Debug 'OpenXPKI::Client::SCEP';
use OpenXPKI::Exception;

extends 'OpenXPKI::Client';

use Data::Dumper;

has service => (
    is      => 'ro',
    isa     => 'Str',
    default => 'SCEP',
);

has server => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Default',
);

has pki_realm => (
    is      => 'ro',
    isa     => 'Str',
    default => '',
);

has encryption_algorithm => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Default',
);

has hash_algorithm => (
    is      => 'ro',
    isa     => 'Str',
    default => 'Default',
);

around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;

    # old call format using hash
    if ( @_ == 1 && ref $_[0] eq 'HASH' ) {
        my %params = %{$_[0]};
        foreach my $key (qw(SERVICE SERVER ENCRYPTION_ALGORITHM HASH_ALGORITHM SOCKETFILE TIMEOUT)) {
            if ($params{$key}) {
                $params{lc($key)} = $params{$key};
                delete $params{$key};
            }
        }
        if ($params{REALM}) {
            $params{pki_realm} = $params{REALM};
            delete $params{REALM};
        }
        return $class->$orig(%params);
    } else {
        return $class->$orig(@_);
    }

};

sub BUILD {

    my $self = shift;
    my $msg;

    $msg = $self->talk('SELECT_PKI_REALM ' . $self->pki_realm());
    if ($msg eq 'NOTFOUND') {
        die("The configured realm (" .$self->pki_realm(). ") was not found "
            . " on the server");
    }

    $msg = $self->talk('SELECT_SERVER ' . $self->server());
    if ($msg eq 'NOTFOUND') {
        die("The configured server (" .$self->server(). ") was not found "
            . " on the server");
    }

    $msg = $self->talk('SELECT_ENCRYPTION_ALGORITHM ' . $self->encryption_algorithm());
    if ($msg eq 'NOTFOUND') {
        die('The configured encryption algorithm (' . $self->encryption_algorithm()
            . ') was not found on the server');
    }

    $msg = $self->talk('SELECT_HASH_ALGORITHM ' . $self->hash_algorithm());
    if ($msg eq 'NOTFOUND') {
        die('The configured hash algorithm (' . $self->hash_algorithm()
            . ') was not found on the server');
    }
}

sub send_request {

    my $self = shift;
    my $op = shift || '';
    my $message = shift || '';
    my $extra_params = shift || {};

    if ($op !~ m{\A(GetCACaps|GetCACert|GetNextCACert|GetCACertChain|PKIOperation)\z}) {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_CLIENT_SCEP_INVALID_OP",
        );
    }

    my $result = $self->send_receive_command_msg($op,{
          MESSAGE => $message,
          URLPARAMS => $extra_params
        }
    );
    $self->close_connection();
    return $result->{PARAMS};

}

1; # Magic true value required at end of module

__END__

=head1 NAME

OpenXPKI::Client::SCEP - OpenXPKI Simple Certificate Enrollment Protocol Client

=head1 SYNOPSIS

    use OpenXPKI::Client::SCEP;

    my $query     = CGI->new();
    my $operation = $query->param('operation');
    my $message   = $query->param('message');

    my $scep_client = OpenXPKI::Client::SCEP->new({
        service    => 'SCEP',
        pki_realm  => $realm,
        socketfile => $socket,
        timeout    => 120,
        server     => $server,
        encryption_algorithm => $enc_alg,
        hash_algorithm => $hash_alg,
        });

    my $result = $scep_client->send_request( $operation, $message );

=head1 DESCRIPTION

OpenXPKI::Client::SCEP acts as a client that sends an SCEP request
to the OpenXPKI server. It is typically called from within a CGI
script that acts as the SCEP server.

=head1 Arguments

=head2 Constructor

=over

=item pki_realm

PKI Realm to access (must match server configuration).

=back

=head2 send_request

Sends SCEP request to OpenXPKI server, expects operation and message as
positional arguments. A third parameter with optional parameters can be
passed which is handed over to the backend workflow as "URLPARAMS".


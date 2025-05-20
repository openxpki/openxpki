package OpenXPKI::Client::API::Response;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Client::API::Response

=head1 SYNOPSIS

The response object to be returned by the execute method of commands.

=cut

=head1 Parameters

=head2 state

The status of the response, encoded as integer. The values used follow
the HTTP status code standard:

=over

=item Z<>200

Successful response

=item Z<>400

Bad request, usually an input validation error.

=item Z<>500

Problems while talking to the backend server or other internal issues.

=back

=cut

has state => (
    is => 'ro',
    isa => 'Int',
    lazy => 1,
    builder => '_init_state',
);

=head2 payload

The result of the operation, usually a hash/list ref with the result of
the command or a OpenXPKI::Field::ValidationExcpetion holding details
of validation errors.

=cut

has payload => (
    is => 'ro',
    isa => 'Item'
);

sub _init_state {

    my $self = shift;
    my $response = $self->payload;

    # if the payload is not a blessed object we assume it is a good response
    return 200 unless (blessed $response);

    # An encapsualted error response from the execution
    # we assume this is a client error
    return 400 if ($response->isa('OpenXPKI::DTO::Message::ErrorResponse'));

    # A good response object
    return 200 if ($response->isa('OpenXPKI::DTO::Message::Response'));

    # no idea what happened - server returned an unknown exception
    return 500;

}

__PACKAGE__->meta()->make_immutable();

1;
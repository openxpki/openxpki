package OpenXPKI::Client::API::Response;

use Moose;


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

=item 200

Successful response

=item 400

Bad request, usually an input validation error.

=item 500

Problems while talking to the backend server or other internal issues.

=over

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
    return 500 unless (blessed $response);

    return 400 if ($response->isa('OpenXPKI::DTO::Message::ErrorResponse'));

    return 200 if ($response->isa('OpenXPKI::DTO::Message::Response'));

    return 500;

}

__PACKAGE__->meta()->make_immutable();

1;
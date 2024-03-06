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
    default => 200,
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

__PACKAGE__->meta()->make_immutable();

1;
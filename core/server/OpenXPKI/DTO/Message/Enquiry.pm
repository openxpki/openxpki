package OpenXPKI::DTO::Message::Enquiry;
use OpenXPKI -class;

with 'OpenXPKI::DTO::Message';

=head1 SYNOPSIS

Run a service query against the server

=head1 Attributes

=head2 topic

Name of the command/method to execute on the backend

=cut

has topic => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

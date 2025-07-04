package OpenXPKI::DTO::Message::Command;
use OpenXPKI -class;

with 'OpenXPKI::DTO::Message';

=head1 SYNOPSIS

Execute a regular command on the backend.

=head1 Attributes

=head2 command

Name of the command/method to execute on the backend

=cut

has command => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

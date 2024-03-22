package OpenXPKI::DTO::Message::ProtectedCommand;

use Moose;
with 'OpenXPKI::DTO::Message';
# Do NOT inherit from Command as this will undermine the security logic!

=head1 SYNOPSIS

Execute a command on the backend which is marked as protected

=head1 Attributes

=head2 command

Name of the command/method to execute on the backend

=cut

has command => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);


1;
package OpenXPKI::Server::Session::DriverRole;
use Moose::Role;
use utf8;

# Project modules
use OpenXPKI::Exception;

=head1 NAME

OpenXPKI::Server::Session::DriverRole - Moose role that every session driver
implementation has to consume

=cut

has 'log' => (
    is => 'ro',
    isa => 'Log::Log4perl::Logger',
    required => 1,
);
has 'data_factory' => (
    is => 'ro',
    isa => 'CodeRef',
    required => 1,
);

################################################################################
# Required in session implementations that consume this role
#
requires 'save';              # argument: $session, should write the attributes to the storage
requires 'load';              # argument: $id, should load data from storage and return a HashRef
requires 'delete';            # argument: $session, should delete the session from the storage
requires 'delete_all_before'; # argument: $epoch, should delete all sessions which were created before the given timestamp

################################################################################
# Methods
#
# Please note that some method names are intentionally chosen to contain action
# prefixes like "get_" to distinct them from the accessor methods of the session
# attributes (data).
#

=head1 REQUIRED METHODS

The following methods are implemented in driver classes that consume this
Moose role.

=head2 save

Writes the session data to the backend storage.

B<Parameters>

=over

=item * $session - a L<OpenXPKI::Server::Session::Data> object

=back

=head2 load

Loads session data from the backend storage.

Returns a L<OpenXPKI::Server::Session::Data> object or I<undef> if the requested
session was not found..

B<Parameters>

=over

=item * $id - ID of the session whose data is to be loaded

=back

=head2 delete

Deletes the session data from the backend storage.

B<Parameters>

=over

=item * $session - a L<OpenXPKI::Server::Session::Data> object

=back

=cut

=head2 delete_all_before

Deletes all sessions from the backend storage which were created before the
given timestamp.

B<Parameters>

=over

=item * $epoch - timestamp

=back

=cut

1;

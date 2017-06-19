package OpenXPKI::Server::Session::DriverRole;
use Moose::Role;
use utf8;

# CPAN modules
use JSON;

# Project modules
use OpenXPKI::Exception;

=head1 NAME

OpenXPKI::Server::Session::DriverRole - Moose role that every session driver
implementation has to consume

=cut

################################################################################
# Required in session implementations that consume this role
#
requires 'save';              # argument: $session, should write the attributes to the storage
requires 'load';              # argument: $id, should load data from storage and return a HashRef
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

=head2 delete_all_before

Deletes all sessions from the backend storage which were created before the
given timestamp.

B<Parameters>

=over

=item * $epoch - timestamp

=back

=head1 STATIC METHODS

=head2 new

Constructor that creates a new session with an empty data object.

=cut

=head1 METHODS

=head2 freeze

Serializes the given HashRef into a string. The first characters of the
string until the first colon indicate the type of serialization (encoder).

Returns a string with the serialized data.

=cut
sub freeze {
    my ($self, $data) = @_;
    return "JSON:".encode_json($data);
}

=head2 thaw

Deserializes the session attributes from a string and returns them as C<HashRef>.

The first characters of the string until the first colon must indicate the type
of serialization (encoder).

=cut
sub thaw {
    my ($self, $frozen) = @_;

    # backwards compatibility
    if ($frozen =~ /^HASH\n/ ) {
        use OpenXPKI::Serialization::Simple;
        return OpenXPKI::Serialization::Simple->new->deserialize($frozen);
    }

    OpenXPKI::Exception->throw(message => "Unknown format of serialized data")
        unless $frozen =~ /^JSON:/;
    $frozen =~ s/^JSON://;

    my $data = decode_json($frozen);
    return $data;
}

1;

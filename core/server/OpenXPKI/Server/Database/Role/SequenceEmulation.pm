package OpenXPKI::Server::Database::Role::SequenceEmulation;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::SequenceEmulation - Moose role for database
drivers to indicate that they have to emulate sequences through a standard table

=cut

################################################################################
# Required in drivers classes that consume this role
#
requires 'last_auto_id';   # String: SQL query to fetch NEXTVAL from sequence

################################################################################
# Methods
#

# Fetches the next insert ID for the given table
sub next_id {
    my ($self, $dbi, $seq) = @_;

    $dbi->insert(
        into => $seq,
        values => { dummy => 0 },
    );
    return $self->last_auto_id($dbi);
}

1;

=head1 Required methods in the consuming driver class

=head2 last_auto_id

Must return the last automatically set ID of an auto increment column.

When called it gets passed the following parameter:

=over

=item * B<$dbi> - instance of L<OpenXPKI::Server::Database>

=back

=cut

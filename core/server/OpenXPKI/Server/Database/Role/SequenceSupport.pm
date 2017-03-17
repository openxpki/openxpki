package OpenXPKI::Server::Database::Role::SequenceSupport;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::SequenceSupport - Moose role for database
drivers to indicate that they support sequences

=cut

################################################################################
# Required in drivers classes that consume this role
#
requires 'nextval_query';   # String: SQL query to fetch NEXTVAL from sequence

################################################################################
# Methods
#

# Returns a query that removes an SQL sequence
sub sequence_drop_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP SEQUENCE $seq",
    );
}

# Fetches the next insert ID for the given table
sub next_id {
    my ($self, $dbi, $seq) = @_;

    my $sth = $dbi->run(
        $self->nextval_query($seq)
    );
    my $row = $sth->fetchrow_arrayref
        or OpenXPKI::Exception->throw(
            message => "Query result for NEXTVAL was empty"
        );
    return $row->[0];
}

1;

=head1 Required methods in the consuming driver class

=head2 nextval_query

Must return the SQL query string to fetch the next sequence value for the given
table.

When called it gets passed the following parameter:

=over

=item * B<$seq_name> - name of the sequence

=back

=cut

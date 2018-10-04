package OpenXPKI::Server::Database::Role::SequenceEmulation;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::SequenceEmulation - Moose role for database
drivers to indicate that they have to emulate sequences through a standard table

=cut

use OpenXPKI::Server::Database::Query;

################################################################################
# Required in drivers classes that consume this role
#
requires 'last_auto_id';   # String: SQL query to fetch NEXTVAL from sequence
requires 'table_drop_query';
requires 'sql_autoinc_column';

################################################################################
# Methods
#

# Returns a query that creates an SQL sequence
sub sequence_create_query {
    my ($self, $dbi, $seq) = @_;
    ## my $info = $dbi->dbh->type_info( [ SQL_SMALLINT, SQL_INTEGER, SQL_DECIMAL ] ); # Does not work for SQlite
    my $autoinc = $self->sql_autoinc_column; # implemented by driver class
    return OpenXPKI::Server::Database::Query->new(
        string => "CREATE TABLE $seq (seq_number $autoinc, dummy SMALLINT DEFAULT NULL)",
    );
}

# Returns a query that removes an SQL sequence
sub sequence_drop_query {
    my ($self, $dbi, $seq) = @_;
    return $self->table_drop_query($dbi, $seq);
}

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

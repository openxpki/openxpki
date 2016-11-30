package OpenXPKI::Server::Database::Role::MergeEmulation;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::MergeEmulation - Moose role for database
drivers to indicate that the DBMS does not provide native support for a MERGE
query

=cut

################################################################################
# Required in drivers classes that consume this role
#


################################################################################
# Methods
#

# SQL MERGE emulation
sub merge_query {
    my ($self, $dbi, $into, $set, $set_once, $where) = @_;

    my $sth = $dbi->select(
        from => $into,
        columns => [ keys %$where ],
        where => $where,
    );
    # UPDATE if data exists
    if ($sth->fetchrow_arrayref) {
        return $dbi->query_builder->update(
            table => $into,
            set   => $set,
            where => $where,
        );
    }
    # INSERT otherwise
    else {
        return $dbi->query_builder->insert(
            into   => $into,
            values => {
                %$set,
                %$set_once,
                %$where,
            },
        );
    }
}

1;

=head1 Description

This role emulates an SQL MERGE (you could also call it REPLACE) query through
SELECT + INSERT/UPDATE.

After a SELECT to check for row existance an INSERT or UPDATE query is built
and an L<OpenXPKI::Server::Database::Query> object returned.

=head1 Required methods in the consuming driver class

None.

=cut

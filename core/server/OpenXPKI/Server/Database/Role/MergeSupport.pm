package OpenXPKI::Server::Database::Role::MergeSupport;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::MergeSupport - Moose role for database
drivers to indicate native support for MERGE (= REPLACE = INSERT or UPDATE).

=cut

use MooseX::Params::Validate;

################################################################################
# Required in drivers classes that consume this role
#
requires 'merge_query';   # OpenXPKI::Server::Database::Query: SQL query to run

################################################################################
# Methods
#

# SQL MERGE
sub merge {
    my $self = shift;
    my $dbi = shift;
    my (undef, %params) = validated_hash([$self, @_],   # MooseX::Params::Validate
        into     => { isa => 'Str' },
        set      => { isa => 'HashRef' },
        set_once => { isa => 'HashRef', optional => 1, default => {} },
        # The WHERE specification contains the primary key columns.
        # In case of an INSERT these will be used as normal values. Therefore
        # we only allow scalars as hash values (which are translated to AND
        # connected "equals" conditions by SQL::Abstract::More).
        where    => { isa => 'HashRef[Value]' },
    );

    my $query = $self->merge_query($dbi, \%params);
    return $dbi->run($query);
}

1;

=head1 Description

This role indicates that the DBMS natively supports SQL MERGE (you could also
call it REPLACE) in some form.

=head1 Required methods in the consuming driver class

=head2 merge_query

Must return the DBMS specific SQL query (L<OpenXPKI::Server::Database::Query>)
that does an SQL MERGE.

When called it gets passed the following parameter (additional to C<$self>):

=over

=item * B<$dbi> - the L<OpenXPKI::Server::Database> instance

=item * B<$params> - I<HashRef> with the query parameters:

    {
        into     => $table,
        set      => { column => "val", column2 => "val" },
        set_once => { keycolumn => "val", insertdate => "2016-11-12" },
        where    => { idcolumn => "val" },
    }

=back

=cut

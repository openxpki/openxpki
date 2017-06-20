package OpenXPKI::Server::Database::Role::MergeSupport;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::MergeSupport - Moose role for database
drivers to indicate native support for MERGE (= REPLACE = INSERT or UPDATE).

=cut

################################################################################
# Required in drivers classes that consume this role
#
requires 'merge_query';   # OpenXPKI::Server::Database::Query: SQL query to run

################################################################################
# Methods
#

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

=item * B<$into> - Table name (I<Str>, required)

=item * B<$set> - Columns that are always set (INSERT or UPDATE). Hash with
column name / value pairs.

=item * B<$set_once> - Columns that are only set on INSERT (additional to those
in the C<where> parameter. Hash with column name / value pairs.

=item * B<$where> - WHERE clause specification that must contain the PRIMARY KEY
columns and only allows "AND" and "equal" operators:
C<<{ col1 => val1, col2 => val2 }>> (I<HashRef>)

=back

=cut

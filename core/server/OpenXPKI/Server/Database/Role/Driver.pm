package OpenXPKI::Server::Database::Role::Driver;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Role::Driver - Moose role that every database driver
has to consume

=cut

################################################################################
# Attributes
#

# Standardize some connection parameters names for all drivers
has 'name'         => ( is => 'ro', isa => 'Str', required => 1 );
has 'namespace'    => ( is => 'ro', isa => 'Str' );    # = schema
has 'host'         => ( is => 'ro', isa => 'Str' );
has 'port'         => ( is => 'ro', isa => 'Int' );
has 'user'         => ( is => 'ro', isa => 'Str' );
has 'passwd'       => ( is => 'ro', isa => 'Str' );

################################################################################
# Required in drivers classes that consume this role
#
requires 'dbi_driver';         # String: DBI compliant case sensitive driver name
requires 'dbi_dsn';            # String: DSN parameters after "dbi:<driver>:"
requires 'dbi_connect_params'; # HashRef: optional parameters to pass to connect()
requires 'sqlam_params';       # HashRef: optional parameters for SQL::Abstract::More
requires 'next_id';            # Int: next insert ID ("serial")
requires 'merge';              # Execute a MERGE query (="REPLACE" = "UPSERT" = UPDATE or INSERT)

1;

=head1 Synopsis

    package OpenXPKI::Server::Database::Driver::MyDB2;
    use Moose;
    with 'OpenXPKI::Server::Database::Role::SequenceSupport';
    with 'OpenXPKI::Server::Database::Role::MergeEmulation';
    with 'OpenXPKI::Server::Database::Role::Driver';

    # required by OpenXPKI::Server::Database::Role::Driver
    sub dbi_driver { 'DB2' }           # DBI compliant driver name
    sub dbi_dsn {                      # DSN string including all parameters.
        my $self = shift;
        return sprintf("dbi:%s:dbname=%s",
            $self->dbi_driver,
            $self->name,
        );
    }
    sub dbi_connect_params { {} }      # Additional parameters for DBI's connect()
    sub sqlam_params { {               # Parameters for SQL::Abstract::More
        limit_offset => 'FetchFirst',
    } }

    # required by OpenXPKI::Server::Database::Role::SequenceSupport
    sub nextval_query {                # SQL query to retrieve next sequence value
        my ($self, $seq) = @_;
        return "VALUES NEXTVAL FOR $seq";
    }

    __PACKAGE__->meta->make_immutable;

Then e.g. in your database.yaml:

    main:
        type: MyDB2
        ...

The above code is actually the current driver for IBM DB2 databases.

=head1 Description

This Moose role must be consumed by every OpenXPKI database driver. It defines
some standard attributes which represent database connection parameters of the
same name (not all are required for every DBMS). Furthermore it requires the
consuming class to implement certain methods.

=head2 Writing an own driver

If you have a DBMS that is not yet supported by OpenXPKI you can write and use
a new driver without changing existing code. The only requirement is that there
is a L<DBI> driver for your DBMS (look for it on
L<MetaCPAN|https://metacpan.org/search?q=DBD%3A%3A&search_type=modules>).

To connect OpenXPKI to your (not yet supported) DBMS follow these steps:

=over

=item 1. Write a driver class in the C<OpenXPKI::Server::Database::Driver::*>
namespace that consumes the following Moose roles:

=over

=item * L<OpenXPKI::Server::Database::Role::SequenceSupport> if your DBMS has native support for sequences,

=item * L<OpenXPKI::Server::Database::Role::SequenceEmulation> otherwise.

=item * L<OpenXPKI::Server::Database::Role::MergeSupport> if your DBMS has native support for some form of an SQL MERGE query (="REPLACE" = "UPSERT" = "INSERT or UPDATE"),

=item * L<OpenXPKI::Server::Database::Role::MergeEmulation> otherwise.

=item * L<OpenXPKI::Server::Database::Role::Driver>

=back

... and implement the methods that these roles require.

=item 2. Reference your driver class by it's driver name (the last part after
C<*::Driver::>, case sensitive) in your configuration file.

=item 3. Submit your code to the OpenXPKI team :)

=back

=head1 Attributes

=over

=item * B<name> - Database name (I<Str>, required)

=item * B<namespace> - Schema/namespace that will be added as table prefix in all queries. Could e.g. be used to store multiple OpenXPKI installations in one database (I<Str>, optional)

=item * B<host> - Database host: IP or hostname (I<Str>, optional)

=item * B<port> - Database TCP port (I<Int>, optional)

=item * B<user> - Database username (I<Str>, optional)

=item * B<passwd> - Database password (I<Str>, optional)

=back

=head1 Methods

Please note that the following methods are implemented in the driver class that
consumes this Moose role.

=head2 dbi_driver

Returns the DBI compliant case sensitive driver name (I<Str>).

=head2 dbi_dsn

Returns the DSN that is passed to L<DBI/connect> (I<Str>).

=head2 dbi_connect_params

Returns optional parameters that are passed to L<DBI/connect> (I<HashRef>).

=head2 sqlam_params

Returns optional parameters that are passed to L<SQL::Abstract::More/new> (I<HashRef>).

=head2 next_id

Returns the next insert id, i.e. the value of the given sequence (I<Int>).

Parameters:

=over

=item * B<$dbi> - OpenXPKI database handler (C<OpenXPKI::Server::Database>, required)

=item * B<$seq> - SQL sequence whose next value shall be returned (I<Str>, required)

=back

=head2 merge

Builds a MERGE query (or emulates it by either an INSERT or an UPDATE query)
and returns a L<OpenXPKI::Server::Database::Query> object which contains SQL
string and bind parameters.

Parameters:

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

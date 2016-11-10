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

1;

=head1 Synopsis

To create a new driver for your "Exotic" DBMS just write a L<Moose> class that
consumes C<OpenXPKI::Server::Database::Role::Driver>:

    package OpenXPKI::Server::Database::Driver::ExoticDb;
    use Moose;
    with 'OpenXPKI::Server::Database::Role::Driver';
    ...

Then e.g. in your database.yaml:

    main:
        type: ExoticDb
        ...

=head1 Description

This class contains the API to interact with the configured OpenXPKI database.

=head1 Attributes

=head2 Constructor parameters

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

Returns the DSN as expected by L<DBI/connect> (I<Str>).

=head2 dbi_connect_params

Return optional parameters to pass to L<DBI/connect> (I<HashRef>).

=head2 sqlam_params

Returns optional parameters to pass to L<SQL::Abstract::More/new> (I<HashRef>).

=head2 next_id

Returns the next insert ID for the given sequence (I<Int>).

Parameters:

=over

=item * B<$dbi> - OpenXPKI database handler (C<OpenXPKI::Server::Database>, required)

=item * B<$seq> - SQL sequence for which an ID shall be returned (I<Str>, required)

=back

=cut

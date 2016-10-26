package OpenXPKI::Server::Database::DriverRole;
use Moose::Role;
use utf8;
=head1 Name

OpenXPKI::Server::Database::DriverRole - Moose role that every DB specific
driver has to fulfill.

=head1 Synopsis

    package OpenXPKI::Server::Database::Driver::ExoticDb;
    use Moose;
    with 'OpenXPKI::Server::Database::DriverRole';
    ...

Then e.g. in your database.yaml:

    main:
        type: ExoticDb
        ...

=head1 Description

This class contains the API to interact with the configured OpenXPKI database.

=cut

#
# Constructor arguments (standard connection parameters for all drivers)
#

has 'name'         => ( is => 'ro', isa => 'Str', required => 1 );
has 'namespace'    => ( is => 'ro', isa => 'Str' );                # = schema
has 'user'         => ( is => 'ro', isa => 'Str' );
has 'passwd'       => ( is => 'ro', isa => 'Str' );

#
# Methods required in classes consuming this role
#

requires 'dbi_driver';         # String: DBI compliant case sensitive driver name
requires 'dbi_dsn';            # String: DSN parameters after "dbi:<driver>:"
requires 'dbi_connect_params'; # HashRef: optional parameters to pass to connect()
requires 'sqlam_params';       # HashRef: optional parameters for SQL::Abstract::More

1;

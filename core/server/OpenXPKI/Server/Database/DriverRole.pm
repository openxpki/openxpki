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

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use DBI::Const::GetInfoType; # provides %GetInfoType hash

#
# Methods required in classes consuming this role
#

requires 'dbi_driver';         # String: DBI compliant case sensitive driver name
requires 'dbi_dsn_params';     # String: DSN parameters after "dbi:<driver>:"
requires 'dbi_connect_attrs';  # HashRef: optional parameters to pass to connect()

#
# Constructor arguments (standard connection parameters for all drivers)
#

has 'name'         => ( is => 'ro', isa => 'Str', required => 1 );
has 'namespace'    => ( is => 'ro', isa => 'Str' );                # = schema
has 'user'         => ( is => 'ro', isa => 'Str' );
has 'passwd'       => ( is => 'ro', isa => 'Str' );

#
# Other attributes
#

# DSN string including all parameters.
has '_dsn' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        return sprintf("dbi:%s:%s", $self->dbi_driver, $self->dbi_dsn_params);
    },
);

has 'connector' => (
    is => 'rw',
    isa => 'DBIx::Handler',
    lazy => 1,
    builder => '_build_connector',
);

sub _build_connector {
    my $self = shift;
    ##! 4: "DSN: ".$self->_dsn
    ##! 4: "User: ".$self->user
    ##! 4: "Additional connect() attributes: " . join " | ", map { $_." = ".$self->dbi_connect_attrs->{$_} } keys %{$self->dbi_connect_attrs}
    return DBIx::Handler->new(
        $self->_dsn,
        $self->user,
        $self->passwd,
        {
            RaiseError => 1,
            AutoCommit => 0,
            %{$self->dbi_connect_attrs},
        }
    );
}

has 'db_version' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    builder => '_build_db_version'
);

sub _build_db_version {
    my $self = shift;
    my $db_version = $self->connector->dbh->get_info($GetInfoType{SQL_DBMS_VER});
    ##! 4: "Database version: $db_version"
    return $db_version;
}

1;

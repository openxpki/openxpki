package OpenXPKI::Server::Database::Driver::Oracle;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::DriverRole';
=head1 Name

OpenXPKI::Server::Database::Driver::Oracle - Driver for Oracle databases

=head1 Description

This driver supports only named connection via TNS names (no host/port setup).

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

# DBI compliant driver name
sub dbi_driver { 'Oracle' };

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;
    return sprintf("dbi:%s:%s",
        $self->dbi_driver,
        $self->name,
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params {
    {
        RaiseError => 1,
        AutoCommit => 0,
        LongReadLen => 10_000_000,
    }
};

# Parameters for SQL::Abstract::More
sub sqlam_params { {} };

__PACKAGE__->meta->make_immutable;

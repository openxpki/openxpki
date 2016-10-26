package OpenXPKI::Server::Database::Driver::SQLite;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::DriverRole';
=head1 Name

OpenXPKI::Server::Database::Driver::SQLite;

=head1 Description

Driver for SQLite databases.

=cut

# DBI compliant driver name
sub dbi_driver { 'SQLite' }

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;
    return sprintf("dbi:%s:dbname=%s",
        $self->dbi_driver,
        $self->name,
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params { {} }

# Parameters for SQL::Abstract::More
sub sqlam_params { {} }

__PACKAGE__->meta->make_immutable;

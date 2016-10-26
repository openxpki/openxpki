package OpenXPKI::Server::Database::Driver::SQLite;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::DriverRole';
=head1 Name

OpenXPKI::Server::Database::Driver::SQLite - Driver for SQLite databases

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

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
sub sqlam_params { {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::Limit source code
} }

__PACKAGE__->meta->make_immutable;

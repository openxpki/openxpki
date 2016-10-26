package OpenXPKI::Server::Database::Driver::PostgreSQL;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::DriverRole';
=head1 Name

OpenXPKI::Server::Database::Driver::PostgreSQL - Driver for PostgreSQL databases

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

# DBI compliant driver name
sub dbi_driver { 'Pg' }

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;
    # map DBI parameter names to our object attributes
    my %args = (
        sslmode => 'allow',
        database => $self->name,
        host => $self->host,
        port => $self->port,
    );
    return sprintf("dbi:%s:%s",
        $self->dbi_driver,
        join(";", map { "$_=$args{$_}" } grep { defined $args{$_} } keys %args), # only add defined attributes
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params { {
    pg_enable_utf8 => 1,
} }

# Parameters for SQL::Abstract::More
sub sqlam_params { {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::Limit source code
} }

__PACKAGE__->meta->make_immutable;

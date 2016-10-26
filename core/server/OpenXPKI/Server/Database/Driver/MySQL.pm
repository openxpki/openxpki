package OpenXPKI::Server::Database::Driver::MySQL;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::DriverRole';
=head1 Name

OpenXPKI::Server::Database::Driver::MySQL - Driver for MySQL/mariaDB databases

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

# DBI compliant driver name
sub dbi_driver { 'mysql' }

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;
    # map DBI parameter names to our object attributes
    my %args = (
        database => $self->name, # from OpenXPKI::Server::Database::DriverRole
        host => $self->host,
        port => $self->port,
    );
    return sprintf("dbi:%s:%s",
        $self->dbi_driver,
        join(";", map { "$_=$args{$_}" } grep { defined $args{$_} } keys %args), # only add defined attributes
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params {
    {
        mysql_enable_utf8 => 1,
        mysql_auto_reconnect => 0, # stolen from DBIx::Connector::Driver::mysql::_connect()
        mysql_bind_type_guessing => 0, # FIXME See https://github.com/openxpki/openxpki/issues/44
    }
}

# Parameters for SQL::Abstract::More
sub sqlam_params { {} }

__PACKAGE__->meta->make_immutable;

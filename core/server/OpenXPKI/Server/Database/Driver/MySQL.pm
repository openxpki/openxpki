package OpenXPKI::Server::Database::Driver::MySQL;
use Moose;
use utf8;
=head1 Name

OpenXPKI::Server::Database::Driver::MySQL;

=head1 Description

Driver for MySQL/mariaDB databases.

=cut

with 'OpenXPKI::Server::Database::DriverRole';

has 'host' => ( is => 'ro', isa => 'Str' );
has 'port' => ( is => 'ro', isa => 'Int' );

#
# Methods required by OpenXPKI::Server::Database::DriverRole
#
sub dbi_driver { 'mysql' };

sub dbi_connect_attrs {
    {
        mysql_enable_utf8 => 1,
        mysql_auto_reconnect => 0, # stolen from DBIx::Connector::Driver::mysql::_connect()
        mysql_bind_type_guessing => 0, # FIXME See https://github.com/openxpki/openxpki/issues/44
    }
};

sub dbi_dsn_params {
    my $self = shift;
    # map DBI parameter names to our object attributes
    my %param_map = (
        database => $self->name, # from OpenXPKI::Server::Database::DriverRole
        host => $self->host,
        port => $self->port,
    );
    # only add defined attributes
    return join ";", map { $_."=".$param_map{$_} } grep { defined $param_map{$_} } keys %param_map;
}

__PACKAGE__->meta->make_immutable;

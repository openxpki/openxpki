package OpenXPKI::Server::Database::Driver::MySQL;
use Moose;
use utf8;
with qw(
    OpenXPKI::Server::Database::Role::SequenceEmulation
    OpenXPKI::Server::Database::Role::MergeSupport
    OpenXPKI::Server::Database::Role::Driver
);

=head1 Name

OpenXPKI::Server::Database::Driver::MySQL - Driver for MySQL/mariaDB databases

=cut

use OpenXPKI::Exception;

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

# DBI compliant driver name
sub dbi_driver { 'mysql' }

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;
    # map DBI parameter names to our object attributes
    my %args = (
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
sub dbi_connect_params {
    mysql_enable_utf8 => 1,
    mysql_auto_reconnect => 0, # stolen from DBIx::Connector::Driver::mysql::_connect()
    mysql_bind_type_guessing => 0, # FIXME See https://github.com/openxpki/openxpki/issues/44
}

# Commands to execute after connecting
sub dbi_on_connect_do {
    "SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED"
}

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::Limit source code
}

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE IF EXISTS $table",
    );
}

################################################################################
# required by OpenXPKI::Server::Database::Role::SequenceEmulation
#

sub sql_autoinc_column { return "INT PRIMARY KEY AUTO_INCREMENT" }

sub last_auto_id {
    my ($self, $dbi) = @_;
    my $sth = $dbi->run('select last_insert_id()');
    my $row = $sth->fetchrow_arrayref;
    return $row->[0];
}

################################################################################
# required by OpenXPKI::Server::Database::Role::MergeSupport
#

sub merge_query {
    my ($self, $dbi, $into, $set, $set_once, $where) = @_;
    my %all_val  = ( %$set, %$set_once, %$where );

    return OpenXPKI::Server::Database::Query->new(
        string => sprintf(
            "INSERT INTO %s (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s",
            $into,
            join(", ", keys %all_val),
            join(", ", map { "?" } (1..scalar keys %all_val)),
            join(", ", map { "$_=?" } keys %$set),
        ),
        params => [
            values %all_val,
            values %$set,
        ]
    );
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

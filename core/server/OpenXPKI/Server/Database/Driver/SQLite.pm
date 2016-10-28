package OpenXPKI::Server::Database::Driver::SQLite;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::Role::Driver';
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

sub last_auto_id {
    my ($self, %params) = validated_hash(\@_,   # MooseX::Params::Validate
        dbi   => { isa => 'OpenXPKI::Server::Database' },
    );
    my $id = $params{dbi}->dbh->func("last_insert_rowid")
        or OpenXPKI::Exception->throw(message => "Failed to query last insert id from database");
    return $id;
}

__PACKAGE__->meta->make_immutable;

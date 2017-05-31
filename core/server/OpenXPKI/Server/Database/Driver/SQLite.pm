package OpenXPKI::Server::Database::Driver::SQLite;
use Moose;
use utf8;
with qw(
    OpenXPKI::Server::Database::Role::SequenceEmulation
    OpenXPKI::Server::Database::Role::MergeEmulation
    OpenXPKI::Server::Database::Role::Driver
);

=head1 Name

OpenXPKI::Server::Database::Driver::SQLite - Driver for SQLite databases

=cut

use OpenXPKI::Exception;

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

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
sub dbi_connect_params {
    sqlite_unicode => 1,
}

# Commands to execute after connecting
sub dbi_on_connect_do { }

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

sub sql_autoinc_column { return "INTEGER PRIMARY KEY AUTOINCREMENT" }

sub last_auto_id {
    my ($self, $dbi) = @_;
    my $id = $dbi->dbh->func("last_insert_rowid");
    return $id;
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

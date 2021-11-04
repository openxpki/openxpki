package OpenXPKI::Server::Database::Driver::SQLite;
use Moose;
use utf8;
with qw(
    OpenXPKI::Server::Database::Role::SequenceEmulation
    OpenXPKI::Server::Database::Role::MergeEmulation
    OpenXPKI::Server::Database::Role::CountEmulation
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
sub on_connect { }

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::Limit source code
}

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE IF EXISTS $table",
    );
}

sub _get_x_from_date {
    my ($part, $date) = @_;

    my $date_map = {
        year => '%Y',
        month => '%m',
        day => '%d',
        hour => '%H',
        minute => '%M',
        second => '%S',
    };
    return sprintf "strftime('%s', %s)", $date_map->{lc($part)}, $date;
}

sub do_sql_replacements {
    my ($self, $sql) = @_;

    $sql =~ s/from_unixtime \s* \( \s* ( [^\)]+ ) \)/DATETIME($1, 'unixepoch')/gmsxi;
    $sql =~ s/extract \s* \( \s* ( [^\)\s]+ ) \s+ from \s+ ( [^\(]* \( [^\)]* \) )* [^\)]* \)/_get_x_from_date($1,$2)/gemsxi;

    return $sql;
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

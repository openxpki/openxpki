package OpenXPKI::Server::Database::Driver::PostgreSQL;
use Moose;
use utf8;
with qw(
    OpenXPKI::Server::Database::Role::SequenceSupport
    OpenXPKI::Server::Database::Role::MergeEmulation
    OpenXPKI::Server::Database::Role::CountEmulation
    OpenXPKI::Server::Database::Role::Driver
);

=head1 Name

OpenXPKI::Server::Database::Driver::PostgreSQL - Driver for PostgreSQL databases

=cut

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

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
sub dbi_connect_params {
    pg_enable_utf8 => 1,
}

# Custom checks after driver instantiation
sub perform_checks { }

# Commands to execute after connecting
sub on_connect {
    my ($self, $dbh) = @_;
    $dbh->do("SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED");
    $dbh->do("SET client_min_messages TO warning");
    $dbh->do("SET lock_timeout TO ?", undef, $self->lock_timeout * 1000);
    # PostgreSQL settings get lost if the current transaction is rolled back, so we commit here.
    # DBI logger and session handler have autocommit on and DBI cause a warning on superflous
    # commits so we need to make this conditional
    $dbh->commit unless($dbh->{AutoCommit});
}

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::More source code
}

sub sequence_create_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "CREATE SEQUENCE $seq START WITH 0 INCREMENT BY 1 MINVALUE 0 NO MAXVALUE",
    );
}

# Returns a query that removes an SQL sequence
sub sequence_drop_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP SEQUENCE IF EXISTS $seq",
    );
}

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE IF EXISTS $table",
    );
}

sub do_sql_replacements {
    my ($self, $sql) = @_;

    $sql =~ s/from_unixtime \s* \( \s* ( [^\)]+ ) \)/TO_TIMESTAMP($1)/gmsxi;

    return $sql;
}

################################################################################
# required by OpenXPKI::Server::Database::Role::SequenceSupport
#

sub nextval_query {
    my ($self, $seq) = @_;
    return "SELECT NEXTVAL('$seq')";
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

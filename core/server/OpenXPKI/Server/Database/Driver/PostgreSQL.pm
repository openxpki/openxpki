package OpenXPKI::Server::Database::Driver::PostgreSQL;
use Moose;
use utf8;
with qw(
    OpenXPKI::Server::Database::Role::SequenceSupport
    OpenXPKI::Server::Database::Role::MergeEmulation
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

# Commands to execute after connecting
sub dbi_on_connect_do {
    "SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED"
}

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::Limit source code
}

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

sub sequence_create_query {
    my ($self, $dbi, $seq) = @_;

    return OpenXPKI::Server::Database::Query->new(
        string => "CREATE SEQUENCE $seq START WITH 0 INCREMENT BY 1 MINVALUE 0 NO MAXVALUE ORDER",
    );
}

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE IF EXISTS $table",
    );
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

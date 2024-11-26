package OpenXPKI::Server::Database::Driver::DB2;
use OpenXPKI -class;

with qw(
    OpenXPKI::Server::Database::Role::SequenceSupport
    OpenXPKI::Server::Database::Role::MergeEmulation
    OpenXPKI::Server::Database::Role::CountEmulation
    OpenXPKI::Server::Database::Role::Driver
);

=head1 Name

OpenXPKI::Server::Database::Driver::DB2 - Driver for IBM DB2 databases

=cut

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

# DBI compliant driver name
sub dbi_driver { 'DB2' }

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;
    return sprintf("dbi:%s:dbname=%s",
        $self->dbi_driver,
        $self->name,
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params { }

# Custom checks after driver instantiation
sub perform_checks { }

# Commands to execute after connecting
sub on_connect { }

# Parameters for SQL::Abstract::More
sub sqlam_params { }

sub sequence_create_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "CREATE SEQUENCE $seq START WITH 0 INCREMENT BY 1 MINVALUE 0 NO MAXVALUE ORDER",
    );
}

# Returns a query that removes an SQL sequence
sub sequence_drop_query {
    my ($self, $dbi, $seq) = @_;
    # TODO For DB2 check if sequence exists before dropping to avoid errors
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP SEQUENCE $seq",
    );
}

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    # TODO For DB2 check if table exists before dropping to avoid errors
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE $table",
    );
}

# FIXME do_sql_replacements() - insert DB2 version of UNIX_TIMESTAMP
#   ...possibly something like:
#   VALUES(CAST("1970-01-01-00.00.00.000000+00:00" AS TIMESTAMP WITH TIME ZONE) + 1611140400 seconds)
sub do_sql_replacements { shift; shift } # return input argument

################################################################################
# required by OpenXPKI::Server::Database::Role::SequenceSupport
#

sub nextval_query {
    my ($self, $seq) = @_;
    return "VALUES NEXTVAL FOR $seq";
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

package OpenXPKI::Server::Database::Driver::Oracle;
use Moose;
use utf8;
with qw(
    OpenXPKI::Server::Database::Role::SequenceSupport
    OpenXPKI::Server::Database::Role::MergeEmulation
    OpenXPKI::Server::Database::Role::Driver
);

=head1 Name

OpenXPKI::Server::Database::Driver::Oracle - Driver for Oracle databases

=cut

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

# DBI compliant driver name
sub dbi_driver { 'Oracle' };

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;

    # Tell Oracle that the client character set is UTF8
    # (assuming that all data that we send is already UTF8 encoded)
    $ENV{"NLS_LANG"} = '.AL32UTF8' unless(defined $ENV{"NLS_LANG"});

    return sprintf("dbi:%s:%s",
        $self->dbi_driver,
        $self->name,
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params { }

# Commands to execute after connecting
sub on_connect { }

# Parameters for SQL::Abstract::More
sub sqlam_params {
    sql_dialect => 'Oracle',
};

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

sub sequence_create_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "CREATE SEQUENCE $seq START WITH 0 INCREMENT BY 1 MINVALUE 0 NOMAXVALUE ORDER",
    );
}

# Returns a query that removes an SQL sequence
sub sequence_drop_query {
    my ($self, $dbi, $seq) = @_;
    # TODO For Oracle check if sequence exists before dropping to avoid errors
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP SEQUENCE $seq",
    );
}

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    # TODO For Oracle check if table exists before dropping to avoid errors
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE $table",
    );
}

sub count_rows {
    my ($self, $dbi, $query) = @_;

    # there is no "as tmp" for the table as in the default method!
    $query->string(sprintf "SELECT COUNT(*) as amount FROM (%s)", $query->string);

    my $sth = $dbi->run($query);
    return $sth->fetchrow_hashref->{amount};
}

################################################################################
# required by OpenXPKI::Server::Database::Role::SequenceSupport
#

sub nextval_query {
    my ($self, $seq) = @_;
    return "SELECT $seq.NEXTVAL FROM DUAL";
}


#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# NOTE ON MERGING:
# We currently have no working solution for native Oracle MERGE support that
# also works with big values (>4000 characters).
#
# The following DOES NOT work for big values:
#    MERGE INTO ..
#    USING (SELECT .. FROM dual) zzzdual ON (..)
#    WHEN MATCHED THEN UPDATE SET ..
#    WHEN NOT MATCHED THEN INSERT (..) VALUES (..)
#
#    "ORA-01461: can bind a LONG value only for insert into a LONG column"
#
# Also experiments with CAST(.. as CLOB) and TO_CLOB(..) failed:
#    "ORA-00932: inconsistent datatypes: expected - got CLOB"
#
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

__PACKAGE__->meta->make_immutable;

=head1 Description

This driver supports only named connection via TNS names (no host/port setup).

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

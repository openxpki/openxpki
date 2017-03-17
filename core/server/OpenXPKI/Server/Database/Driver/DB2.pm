package OpenXPKI::Server::Database::Driver::DB2;
use Moose;
use utf8;
with qw(
    OpenXPKI::Server::Database::Role::SequenceSupport
    OpenXPKI::Server::Database::Role::MergeEmulation
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

# Commands to execute after connecting
sub dbi_on_connect_do { }

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'FetchFirst',    # see SQL::Abstract::Limit source code
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
    # TODO For DB2 check if table exists before dropping to avoid errors
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE $table",
    );
}

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

package OpenXPKI::Server::Database::Driver::Oracle;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::Role::SequenceSupport';
with 'OpenXPKI::Server::Database::Role::MergeSupport';
with 'OpenXPKI::Server::Database::Role::Driver';

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
    return sprintf("dbi:%s:%s",
        $self->dbi_driver,
        $self->name,
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params { };

# Parameters for SQL::Abstract::More
sub sqlam_params {
    sql_dialect => 'Oracle',
};

################################################################################
# required by OpenXPKI::Server::Database::Role::SequenceSupport
#

sub nextval_query {
    my ($self, $seq) = @_;
    return "SELECT $seq.NEXTVAL FROM DUAL";
}

################################################################################
# required by OpenXPKI::Server::Database::Role::MergeSupport
#

sub merge_query {
    my ($self, $dbi, $into, $set, $set_once, $where) = @_;
    my %all_val  = ( %$set, %$set_once, %$where );

    return OpenXPKI::Server::Database::Query->new(
        # this special query avoids binding/typing the values twice
        string => sprintf(
            "MERGE INTO %s"
            ." USING (SELECT %s FROM dual) zzzdual ON (%s)"
            ." WHEN MATCHED THEN UPDATE SET %s"
            ." WHEN NOT MATCHED THEN INSERT (%s) VALUES (%s)",
            $into,
            join (", ", map { "? AS $_" } keys %all_val),              # SELECT .. FROM dual
            join(" AND ", map { "$into.$_=zzzdual.$_" } keys %$where), # ON (..)
            join(", ", map { "$into.$_=zzzdual.$_" } keys %$set),      # UPDATE SET ..
            join(", ", keys %all_val),                                 # INSERT (..)
            join(", ", map { "zzzdual.$_" } keys %all_val),            # VALUES (..)
        ),
        params => [ values %all_val ],
    );
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This driver supports only named connection via TNS names (no host/port setup).

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

package OpenXPKI::Server::Database::Driver::DB2;
use Moose;
use utf8;
with 'OpenXPKI::Server::Database::Role::SequenceSupport';
with 'OpenXPKI::Server::Database::Role::MergeEmulation';
with 'OpenXPKI::Server::Database::Role::Driver';

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

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'FetchFirst',    # see SQL::Abstract::Limit source code
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

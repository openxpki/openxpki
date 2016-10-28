package OpenXPKI::Server::Database;
use Moose;
use utf8;
=head1 Name

OpenXPKI::Server::Database - Entry point for database related functions

=cut

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Database::Connector;


## TODO special handling for SQLite databases from OpenXPKI::Server::Init->get_dbi()
# if ($params{TYPE} eq "SQLite") {
#     if (defined $args->{PURPOSE} && ($args->{PURPOSE} ne "")) {
#         $params{NAME} .= "._" . $args->{PURPOSE} . "_";
#         ##! 16: 'SQLite, name: ' . $params{NAME}
#     }
# }


################################################################################
# Attributes
#
has 'log' => (
    is => 'ro',
    isa => 'Object',
    required => 1,
);

# Parameters to construct DSN
has 'db_params' => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

# Connection handler
has '_connector' => (
    is => 'ro',
    does => 'OpenXPKI::Server::Database::Connector',
    lazy => 1,
    builder => '_build_connector',
    handles => [
        'dbh',
        'start_txn',
        'commit',
        'rollback',
        'query_builder',
        'run',
    ],
);
    
################################################################################
# Builders
#
sub _build_connector {
    my $self = shift;
    return OpenXPKI::Server::Database::Connector->new(db_params => $self->db_params);
}

################################################################################
# Methods
#

# SELECT
# Returns: DBI statement handle
sub select {
    my $self = shift;
    my $query = $self->query_builder->select(@_);
    return $self->run($query);
}

# SELECT - return first row
# Returns: DBI statement handle
sub select_one {
    my $self = shift;
    my $sth = $self->select(@_);
    return $sth->fetchrow_hashref;
}

# INSERT
# Returns: DBI statement handle
sub insert {
    my $self = shift;
    my $query = $self->query_builder->insert(@_);
    return $self->run($query);
}

# UPDATE
# Returns: DBI statement handle
sub update {
    my $self = shift;
    my $query = $self->query_builder->update(@_);
    return $self->run($query);
}

__PACKAGE__->meta->make_immutable;

=head1 Synopsis

    my $db = OpenXPKI::Server::Database->new(
        log => $log_object,
        db_params => {
            type   => 'MySQL',
            name   => 'openxpki',
            host   => '127.0.0.1',
            user   => 'oxi',
            passwd => 'gen',
        }
    );

    # total count
    my $tuple = $db->select_one(
        from => 'certificate',
        columns  => [ 'COUNT(identifier)|amount' ],
        where => {
            req_key => { '!=' => undef },
            pki_realm => 'ca-one',
        }
    );
    printf "Total count: %i\n", $tuple->{amount};

=head1 Description

This class contains the API to interact with the configured OpenXPKI database.

While OpenXPKI supports several database types out of the box it still allows
you to include new DBMS specific drivers without the need to change existing
code. This can be achieved by:

=over

=item 1. Writing a driver class in the C<OpenXPKI::Server::Database::Driver::*>
namespace that consumes the Moose role L<OpenXPKI::Server::Database::DriverRole>

=item 2. Referencing this class in your config.

=back

For a short example see L<OpenXPKI::Server::Database::DriverRole/Synopsis>.

=head2 Class structure

    +-------------+
    | *::Database |
    +--+----------+
       |
       |  +------------------------+
       +-^+ *::Database::Connector |
          +--+-+-+-----------------+
             | | |
             | | |  +---------------------------+
             | | +--> *::Database::DriverRole   |
             | |    +---------------------------+
             | |
             | |    +---------------------------+
             | +----> *::Database::QueryBuilder +---+
             |      +---------------------------+   |
             |                                      |
             |      +---------------------------+   |
             +------> *::Database::Query        <---+
                    +---------------------------+

=head1 Attributes

=head2 Constructor parameters

=over

=item * B<log> - Log object (I<OpenXPKI::Server::Log>, required)

=item * B<db_params> - I<HashRef> with parameters for the DBI data source name
string.

Required keys in this hash:

=over

=item * B<type> - last part of a package in the C<OpenXPKI::Server::Database::Driver::*> namespace. (I<Str>, required)

=item * Any of the L<OpenXPKI::Server::Database::DriverRole/Constructor parameters>

=item * Additional parameters required by the specific driver

=back

=back

=head1 Methods

=head2 new

Constructor.

Named parameters: see L<attributes section above|/"Constructor parameters">.

=head2 select

Selects rows from the database and returns the results as a I<DBI::st> statement
handle.

Please note that C<NULL> values will be converted to Perl C<undef>.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/select>.

=head2 select_one

Selects one row from the database and returns the results as a I<HashRef>
(column name => value) by calling C<$sth-E<gt>fetchrow_hashref>.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/select>.

Returns C<undef> if the query had no results.

Please note that C<NULL> values will be converted to Perl C<undef>.

=head2 insert

Inserts the given data into the database.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/insert>.

Returns the statement handle.

Please note that Perl C<undef> will be converted to C<NULL>.

=head2 insert

Inserts rows into the database and returns the results as a I<DBI::st> statement
handle.

Please note that C<NULL> values will be converted to Perl C<undef>.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/insert>.

=head2 update

Updates rows in the database and returns the results as a I<DBI::st> statement
handle.

Please note that C<NULL> values will be converted to Perl C<undef>.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/update>.

=head2 start_txn

Starts a new transaction via C<$dbh-E<gt>begin_work>.

Transactions can be virtually nested, i.e. code with C<start_txn> and C<commit>
can later be surrounded by another pair of these functions. The result is that
only the outermost method calls will have any (database) effect.

In other words: if this method is called again before any rollback or commit
then:

=over

=item 1. the nesting level counter will be increased

=item 2. B<no> action will be performed on the database

=back

=head2 commit

Commits a transaction.

If currently in a nested transaction, decreases the nesting level counter.

croaks if there was a rollback in a nested transaction.

=head2 rollback

Rolls back a transaction.

If currently in a nested transaction, notes the rollback for later and decreases
the nesting level counter.

=cut

################################################################################

=head1 Low level methods

The following methods allow more fine grained control over the query processing.

=head2 query_builder

Returns an L<OpenXPKI::Server::Database::QueryBuilder> object which allows to
start build new abstract SQL queries.

Usage:

    my $query = $db->query_builder->select(
        from => 'certificate',
        columns  => [ 'identifier' ],
        where => { pki_realm => 'ca-one' },
    );
    # returns an OpenXPKI::Server::Database::Query object

=head2 run

Executes the given query and returns a DBI statement handle.

    my $sth = $db->run($query) or die "Error executing query: $@";

Parameters:

=over

=item * B<$query> - query to run (I<OpenXPKI::Server::Database::Query>)

=back

=head2 dbh

Returns a fork safe L<DBI> database handle.

=cut

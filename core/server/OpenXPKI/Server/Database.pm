package OpenXPKI::Server::Database;
use Moose;
use utf8;
=head1 Name

OpenXPKI::Server::Database::DriverRole - Common database functions and role
that every DB specific driver has to fulfill.

=head1 Synopsis

    package OpenXPKI::Server::Database::Driver::ExoticDb;
    use Moose;
    with 'OpenXPKI::Server::Database::DriverRole';
    ...

Then e.g. in your database.yaml:

    main:
        type: ExoticDb
        ...

=head1 Description

This class contains the API to interact with the configured OpenXPKI database.

=cut

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Database::Connector;
use OpenXPKI::Server::Database::Query;
use DBIx::Handler;


## TODO special handling for SQLite databases from OpenXPKI::Server::Init->get_dbi()
# if ($params{TYPE} eq "SQLite") {
#     if (defined $args->{PURPOSE} && ($args->{PURPOSE} ne "")) {
#         $params{NAME} .= "._" . $args->{PURPOSE} . "_";
#         ##! 16: 'SQLite, name: ' . $params{NAME}
#     }
# }



#
# Constructor arguments
#

has 'log' => (
    is => 'ro',
    isa => 'Object',
    required => 1,
);

=head2 dsn_params

Required parameters:

=over

=item * B<db_type> - last part of a package in the OpenXPKI::Server::Database::Driver::* namespace. (I<Str>, required)

=item * All parameters required by the specific driver class

=back

=cut
has 'dsn_params' => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

#
# Other attributes
#
has 'connector' => (
    is => 'ro',
    does => 'OpenXPKI::Server::Database::Connector',
    lazy => 1,
    builder => '_build_connector',
    handles => [
        'dbh',
        'query',
        'start_txn',
        'commit',
        'rollback',
    ],
);
sub _build_connector {
    my $self = shift;
    return OpenXPKI::Server::Database::Connector->new(dsn_params => $self->dsn_params);
}

# SELECT - Return all rows
# Returns: A DBI::st statement handle
sub select {
    my $self = shift;
    my $query = $self->query->select(@_);
    return $self->run($query);
}

# SELECT - Return first result row
# Returns: HashRef containing the result columns (C<$sth-E<gt>fetchrow_hashref>)
# or C<undef> if query had no results.
sub select_one {
    my $self = shift;
    my $sth = $self->select(@_);
    my $tuple = $sth->fetchrow_hashref or return;
    return $tuple;
}

# INSERT
# Returns: The statement handle
sub insert {
    my $self = shift;
    my $query = $self->query->insert(@_);
    ##! 4: "Query: " . $query->sql_str;
    my $sth = $self->run($query);
    return $sth;
}

# Execute given query
sub run {
    my ($self, $query) = @_;

    ##! 2: "Query: " . $query->sql_str;
    my $sth = $self->dbh->prepare($query->sql_str);
    $query->bind_params_to($sth);           # let SQL::Abstract::More do some magic
    $sth->execute;

    return $sth;
}

__PACKAGE__->meta->make_immutable;


=head1 Name

OpenXPKI::Server::Database - Entry point for database related functions

=head1 Synopsis

    my $db = OpenXPKI::Server::Database->new({
        log         => $log_object,
        db_type     => 'mysql',
        db_name     => 'openxpki',
        db_host     => '127.0.0.1',
        db_user     => 'oxi',
        db_passwd => 'gen',
    });

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

=head1 Attributes

=head2 Set via constructor

=over

=item * B<log> - Log object (I<OpenXPKI::Server::Log>, required)

=item * B<db_type> - DBI compliant case sensitive driver name (I<Str>, required)

=item * B<db_name> - Database name (I<Str>, required)

=item * B<db_namespace> - Schema/namespace that will be added as table prefix in all queries. Could e.g. be used to store multiple OpenXPKI installations in one database (I<Str>)

=item * B<db_host> - Database host: IP or hostname (I<Str>)

=item * B<db_port> - Database TCP port (I<Int>)

=item * B<db_user> - Database username (I<Str>)

=item * B<db_passwd> - Database password (I<Str>)

=back

=head2 Others

=over

=item * B<db_version> - Database version, automatically set to the result of C<$dbh-E<gt>get_version(...)>' (I<Str>)

=back

=head1 Methods

=head2 factory

Static call that creates a driver specific child of this class.
Do B<not> call new on this class directly.

Named parameters:

=over

=item * See L<attributes section above|/"Set via constructor">

=back

=head2 select

Selects rows from the database and returns the results as a I<DBI::st> statement
handle.

Please note that C<NULL> values will be converted to Perl C<undef>.

For parameters see L<OpenXPKI::Server::Database::Query/select>.

=head2 select_one

Selects one row from the database and returns the results as a I<HashRef>
(column name => value). Returns C<undef> if the query had no results.

Please note that C<NULL> values will be converted to Perl C<undef>.

For parameters see L<OpenXPKI::Server::Database::Query/select>.

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

=head1 Low level methods

The following methods allow more fine grained control over the query processing.

=head2 dbh

Returns a fork safe L<DBI> database handle.

=head2 query

Starts a new query by returning an L<OpenXPKI::Server::Database::Query> object.

Usage:

    my $query = $db->query->select(
        from => 'certificate',
        columns  => [ 'identifier' ],
        where => { pki_realm => 'ca-one' },
    );

=head2 run

Runs the given query and returns a DBI statement handle.

    my $sth = $db->run($query) or die "Error executing query: $@";

Parameters:

=over

=item * B<$query> - Query to run (I<OpenXPKI::Server::Database::Query>)

=back

=cut

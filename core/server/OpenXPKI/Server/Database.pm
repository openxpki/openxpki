package OpenXPKI::Server::Database;

use strict;
use warnings;
use utf8;
use English;

use Moose;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Database::Query;
use DBIx::Handler;
use DBI::Const::GetInfoType;

#
# Constructor arguments
#
has 'log'             => ( is => 'ro', isa => 'Object', required => 1 );
has 'db_type'         => ( is => 'rw', isa => 'Str',    required => 1 ); # DBI compliant case sensitive driver name
has 'db_name'         => ( is => 'ro', isa => 'Str',    required => 1 );
has 'db_namespace'    => ( is => 'ro', isa => 'Str' );                # = schema
has 'db_host'         => ( is => 'ro', isa => 'Str' );
has 'db_port'         => ( is => 'ro', isa => 'Int' );
has 'db_user'         => ( is => 'ro', isa => 'Str' );
has 'db_passwd'       => ( is => 'ro', isa => 'Str' );

#
# Other attributes
#

has 'db_version' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    builder => '_build_db_version'
);

sub _build_db_version {
    my $self = shift;
    my $db_version = $self->_connector->dbh->get_info($GetInfoType{SQL_DBMS_VER});
    ##! 4: "Database version: $db_version"
    return $db_version;
}

has '_connector' => (
    is => 'rw',
    isa => 'DBIx::Handler',
    lazy => 1,
    builder => '_build_connector',
);

sub _build_connector {
    my $self = shift;
    ##! 4: "DSN: ".$self->_dsn
    ##! 4: "DSN attributes: " . join " | ", map { $_." = ".$self->_dsn_attrs->{$_} } keys %{$self->_dsn_attrs}
    my $conn = DBIx::Handler->new($self->_dsn, $self->db_user, $self->db_passwd, $self->_dsn_attrs);
}

has '_dsn' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my %param_map = (
            database => $self->db_name,
            host => $self->db_host,
            port => $self->db_port,
        );
        # only add defined attributes
        my $dsn_params = join ";", map { $_."=".$param_map{$_} } grep { defined $param_map{$_} } keys %param_map;
        # compose DSN and attributes
        return sprintf("dbi:%s:%s", $self->db_type, $dsn_params);
    },
);

has '_dsn_attrs' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {
        RaiseError => 1,
        AutoCommit => 0,
    } },
    traits  => ['Hash'],
    handles => { _add_dsn_attr => 'set' },
);

# Constructor
sub BUILD {
    my $self = shift;

    # FIXME Drop support for legacy DB driver configuration (= not DBI compliant)
    $self->db_type('mysql')  if $self->db_type =~ /mysql/i;
    $self->db_type('Oracle') if $self->db_type =~ /oracle/i;

    #******************************
    # MYSQL - custom behaviour
    if ('mysql' eq $self->db_type) {
        $self->_add_dsn_attr(
            mysql_enable_utf8 => 1,
            mysql_auto_reconnect => 0, # stolen from DBIx::Connector::Driver::mysql::_connect()
            mysql_bind_type_guessing => 0, # FIXME See https://github.com/openxpki/openxpki/issues/44
        );
    }
    #******************************
    # ORACLE - custom behaviour
    elsif ('Oracle' eq $self->db_type) {
        OpenXPKI::Exception->throw(
            message => "Only named connections via TNS are supported for Oracle databases (please remove host and port specifications from your configuration)",
        ) if ($self->db_host or $self->db_port);

        $self->_dsn(sprintf("dbi:%s:%s", $self->db_type, $self->db_name));
        $self->_add_dsn_attr(
            LongReadLen => 10_000_000,
        );
    }

    # TODO Use PostgreSQL DB option: pg_enable_utf8 => 1
}

# Returns a fork safe DBI handle
sub dbh {
    my $self = shift;
    # If this is too slow due to DB pings, we could pass "no_ping" attribute to
    # DBIx::Handler and copy the "fixup" code from DBIx::Connector::_fixup_run()
    my $dbh = $self->_connector->dbh;        # fork safe DBI handle
    $dbh->{FetchHashKeyName} = 'NAME_lc';    # enforce lowercase names
    return $dbh;
}

# Returns a new L<OpenXPKI::Server::Database::Query> object.
sub query {
    my $self = shift;
    return OpenXPKI::Server::Database::Query->new(
        db_type => $self->db_type,
        db_version => $self->db_version,
        $self->db_namespace ? (db_namespace => $self->db_namespace) : (),
    );
}

# SELECT - Return all rows
# Returns: A DBI::st statement handle
sub select {
    my $self = shift;
    my $query = $self->query->select(@_);
    ##! 4: "Query: " . $query->sql_str;

    return $self->run($query);
}

# SELECT - Return first result row
# Returns: HashRef containing the result columns (C<$sth-E<gt>fetchrow_hashref>)
sub select_one {
    my $self = shift;
    my $sth = $self->select(@_) or return;

    my $tuple = $sth->fetchrow_hashref
        or die "Query had no results\n";
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

    my $sth = $self->dbh->prepare($query->sql_str);
    $query->bind_params_to($sth);           # let SQL::Abstract::More do some magic
    $sth->execute;

    return $sth;
}

sub start_txn {
    my $self = shift;
    $self->_connector->txn_begin;
}

sub commit {
    my $self = shift;
    $self->_connector->txn_commit;
}

sub rollback {
    my $self = shift;
    $self->_connector->txn_rollback;
}

1;

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

For Oracle databases only named connections via TNS names are supported
(no host/port setup).

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

Please note that C<NULL> will be returned as C<undef>.

For parameters see L<OpenXPKI::Server::Database::Query/select>.

=head2 select_one

Selects one row from the database and returns the results as a I<HashRef>
(column name => value).

Please note that C<NULL> will be returned as C<undef>.

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

package OpenXPKI::Server::Database;
use Moose;
use utf8;
=head1 Name

OpenXPKI::Server::Database - Handles database connections and encapsulates DB
specific drivers/functions.

=cut

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Database::Util;
use OpenXPKI::Server::Database::Role::Driver;
use OpenXPKI::Server::Database::QueryBuilder;
use OpenXPKI::Server::Database::Query;
use DBIx::Handler;
use DBI::Const::GetInfoType; # provides %GetInfoType hash
use Math::BigInt;
use SQL::Abstract::More;

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

has 'driver' => (
    is => 'ro',
    does => 'OpenXPKI::Server::Database::Role::Driver',
    lazy => 1,
    builder => '_build_driver',
);

has 'query_builder' => (
    is => 'ro',
    isa => 'OpenXPKI::Server::Database::QueryBuilder',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Server::Database::QueryBuilder->new(
            sqlam => $self->sqlam,
            $self->driver->namespace ? (namespace => $self->driver->namespace) : (),
        );
    },
);

has 'sqlam' => ( # SQL query builder
    is => 'rw',
    isa => 'SQL::Abstract::More',
    lazy => 1,
    default => sub {
        my $self = shift;
        my @return = $self->driver->sqlam_params; # use array to get list context
        # tolerate different return values: undef, list, HashRef
        return SQL::Abstract::More->new(
            $self->_driver_return_val_to_list(
                \@return,
                ref($self->driver)."::sqlam_params",
            )
        );
    },
    # TODO Support Oracle 12c LIMIT syntax: OFFSET 4 ROWS FETCH NEXT 4 ROWS ONLY
    # TODO Support LIMIT for other DBs by giving a custom sub to "limit_offset"
);

has 'db_version' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->dbh->get_info($GetInfoType{SQL_DBMS_VER});
    },
);

has '_dbix_handler' => (
    is => 'rw',
    isa => 'DBIx::Handler',
    lazy => 1,
    builder => '_build_dbix_handler',
    predicate => '_dbix_handler_initialized', # for test cases
    handles => {
        disconnect => 'disconnect',
    },
);

# stores the caller() information about the code that started a transaction
has '_txn_starter' => (
    is => 'rw',
    isa => 'Any',
    clearer => '_clear_txn_starter',
    predicate => 'in_txn',
);

################################################################################
# Builders
#

sub _build_driver {
    my $self = shift;
    my %args = %{$self->db_params}; # copy hash

    my $driver = $args{type};
    OpenXPKI::Exception->throw (
        message => "Parameter 'type' missing: it must equal the last part of a package in the OpenXPKI::Server::Database::Driver::* namespace.",
    ) unless $driver;
    delete $args{type};

    my $class = "OpenXPKI::Server::Database::Driver::".$driver;

    eval { use Module::Load; autoload($class) };
    OpenXPKI::Exception->throw (
        message => "Unable to require() database driver package",
        params => { class_name => $class, message => $@ }
    ) if $@;

    my $instance;
    eval { $instance = $class->new(%args) };
    OpenXPKI::Exception->throw (
        message => "Unable to instantiate database driver class",
        params => { class_name => $class, message => $@ }
    ) if $@;

    OpenXPKI::Exception->throw (
        message => "Database driver class does not seem to be a Moose class",
        params => { class_name => $class }
    ) unless $instance->can('does');

    OpenXPKI::Exception->throw (
        message => "Database driver class does not consume role OpenXPKI::Server::Database::Role::Driver",
        params => { class_name => $class }
    ) unless $instance->does('OpenXPKI::Server::Database::Role::Driver');

    return $instance;
}

sub _build_dbix_handler {
    my $self = shift;
    ##! 4: "DSN: ".$self->driver->dbi_dsn
    ##! 4: "User: ".($self->driver->user // '(none)')
    my %params = $self->_driver_return_val_to_list(
        [ $self->driver->dbi_connect_params ], # driver might return a list so we enforce list context
        ref($self->driver)."::dbi_connect_params",
    );
    ##! 4: "Additional connect() attributes: " . join " | ", map { $_." = ".$params{$_} } keys %params
    my $dbix = DBIx::Handler->new(
        $self->driver->dbi_dsn,
        $self->driver->user,
        $self->driver->passwd,
        {
            RaiseError => 0,
            PrintError => 0,
            AutoCommit => 0,
            LongReadLen => 10_000_000,
            # on_connect_do is (also) called after fork():
            # then we get a new DBI handle and a previous transaction is invalid
            on_connect_do => sub { shift->_clear_txn_starter },
            %params,
        }
    ) or OpenXPKI::Exception->throw(
        message => "Could not connect to database",
        params => {
            dbi_error => $DBI::errstr,
            dsn => $self->driver->dbi_dsn,
            user => $self->driver->user,
        },
    );
    return $dbix;
}

################################################################################
# Methods
#

sub _driver_return_val_to_list {
    my ($self, $return, $method) = @_;
    my $params;
    if (scalar @$return == 0) {             # undef
        $params = {};
    }
    elsif (scalar @$return > 1) {           # list
        $params = { @$return };
    }
    elsif (ref $return->[0] eq 'HASH') {    # HashRef
        $params = $return->[0];
    }
    else {
        OpenXPKI::Exception->throw (
            message => "Faulty driver implementation: '$method' did not return undef, a HashRef or a list",
        );
    }
    return %$params;
}

sub dbh {
    my $self = shift;
    # If this is too slow due to DB pings, we could pass "no_ping" attribute to
    # DBIx::Handler and copy the "fixup" code from DBIx::Connector::_fixup_run()
    my $dbh = $self->_dbix_handler->dbh;     # fork safe DBI handle
    $dbh->{FetchHashKeyName} = 'NAME_lc';    # enforce lowercase names
    return $dbh;
}

# Execute given query
sub run {
    my $self = shift;
    my ($query) = positional_args(\@_,
        { isa => 'OpenXPKI::Server::Database::Query|Str' },
    );
    my $query_string;
    my $query_params;
    if (ref $query) {
        $query_string = $query->string;
        $query_params = $query->params;
    }
    else {
        $query_string = $query;
    }
    ##! 16: "Query: " . $query_string;
    my $sth = $self->dbh->prepare($query_string)
        or OpenXPKI::Exception->throw(
            message => "Could not prepare SQL query",
            params => {
                query => $query_string,
                dbi_error => $self->dbh->errstr,
            },
        );

    # bind parameters via SQL::Abstract::More to do some magic
    if ($query_params) {
        $self->sqlam->bind_params($sth, @{$query_params}); # can't use "or ..." here
        OpenXPKI::Exception->throw(
            message => "Could not bind parameters to SQL statement",
            params => {
                query => $query_string,
                dbi_error => $sth->errstr,
            },
        ) if $sth->err;
    }

    $sth->execute
        or OpenXPKI::Exception->throw(
            message => "Could not execute SQL query",
            params => {
                query => $query_string,
                dbi_error => $sth->errstr,
            },
        );

    return $sth;
}

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

# MERGE
# Returns: DBI statement handle
sub merge {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::Server::Database::Util
        into     => { isa => 'Str' },
        set      => { isa => 'HashRef' },
        set_once => { isa => 'HashRef', optional => 1, default => {} },
        # The WHERE specification contains the primary key columns.
        # In case of an INSERT these will be used as normal values. Therefore
        # we only allow scalars as hash values (which are translated to AND
        # connected "equals" conditions by SQL::Abstract::More).
        where    => { isa => 'HashRef[Value]' },
    );
    my $query = $self->driver->merge_query(
        $self,
        $self->query_builder->_add_namespace_to($args{into}),
        $args{set},
        $args{set_once},
        $args{where},
    );
    return $self->run($query);
}

# DELETE
# Returns: DBI statement handle
sub delete {
    my $self = shift;
    my $query = $self->query_builder->delete(@_);
    return $self->run($query);
}

# Create a new insert ID ("serial")
sub next_id {
    my ($self, $table) = @_;

    # get new serial number from DBMS (SQL sequence or emulation via table)
    my $id_int = $self->driver->next_id($self, "seq_$table");
    my $id = Math::BigInt->new($id_int);
    ##! 32: 'Next ID: ' . $id->bstr()

    # shift bitwise left and add server id (default: 255)
    my $nodeid_bits = $self->db_params->{server_shift} // 8;
    my $nodeid      = $self->db_params->{server_id} // 2 ** $nodeid_bits - 1;
    $id->blsft($nodeid_bits);
    $id->bior(Math::BigInt->new($nodeid));

    return $id->bstr();
}

sub start_txn {
    my $self = shift;
    if ($self->in_txn) {
        $self->log->error(
            sprintf "start_txn() was called during a running transaction (started in %s, line %i). Most likely this error is caused by a missing commit() or exception handling without rollback()",
            $self->_txn_starter->[1],
            $self->_txn_starter->[2],
        );
        $self->rollback;
    }
    ##! 16: "Flagging a transaction start"
    $self->_txn_starter([ caller ]);
}

sub commit {
    my $self = shift;
    $self->log->warn("commit() was called without indicating a transaction start via start_txn() first")
        unless $self->in_txn;
    ##! 16: "Commit of changes"
    $self->dbh->commit;
    $self->_clear_txn_starter;
}

sub rollback {
    my $self = shift;
    $self->log->warn("rollback() was called without indicating a transaction start via start_txn() first")
        unless $self->in_txn;
    ##! 16: "Rollback of changes"
    $self->dbh->rollback;
    $self->_clear_txn_starter;
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class contains the API to interact with the configured OpenXPKI database.

=head2 Database drivers

While OpenXPKI supports several database types out of the box it still allows
you to include new DBMS specific drivers without the need to change existing
code.

For more details see L<OpenXPKI::Server::Database::Role::Driver>.

=head2 Class structure

=cut

# The diagram was drawn using App::Asciio

=pod

         .----------------------------.
    .----| OpenXPKI::Server::Database |---.--------------------.
    |    '----------------------------'   |                    |
    |                   |                 |                    |
    |                   |                 v                    v
    |                   |      .---------------------. .---------------.
    |             .-----'      | SQL::Abstract::More | | DBIx::Handler |
    |             |            '---------------------' '---------------'
    |             |                       .
    |             v                   injected
    |  .---------------------.            .
    |  | O:S:D::QueryBuilder |<...........'
    |  '---------------------'
    |             |     .--------------.
    |             '---->| O:S:D::Query |
    |                   '--------------'
    |
    |  .------------------.
    '->| O:S:D::Driver::* |
       '------------------'
         .
       consumes
         .    .---------------------.
         ....>| O:S:D::Role::Driver |
         .    '---------------------'
         .    .------------------------------.    .--------------------------------.
         ....>| O:S:D::Role::SequenceSupport | or | O:S:D::Role::SequenceEmulation |
         .    '------------------------------'    '--------------------------------'
         .    .------------------------------.    .--------------------------------.
         '...>| O:S:D::Role::MergeSupport    | or | O:S:D::Role::MergeEmulation    |
              '------------------------------'    '--------------------------------'

=head1 Attributes

=head2 Constructor parameters

=over

=item * B<log> - Log object (I<OpenXPKI::Server::Log>, required)

=item * B<db_params> - I<HashRef> with parameters for the DBI data source name
string.

Required keys in this hash:

=over

=item * B<type> - last part of a package in the C<OpenXPKI::Server::Database::Driver::*> namespace. (I<Str>, required)

=item * Any of the L<OpenXPKI::Server::Database::Role::Driver/Constructor parameters>

=item * Additional parameters required by the specific driver

=back

=back

=head2 Others

=over

=item * B<driver> - database specific driver instance (consumer of L<OpenXPKI::Server::Database::Role::Driver>)

=item * B<query_builder> - OpenXPKI query builder to create abstract SQL queries (L<OpenXPKI::Server::Database::QueryBuilder>)

Usage:

    my $query = $db->query_builder->select(
        from => 'certificate',
        columns  => [ 'identifier' ],
        where => { pki_realm => 'ca-one' },
    );
    # returns an OpenXPKI::Server::Database::Query object

=item * B<db_version> - database version, equals the result of C<$dbh-E<gt>get_version(...)> (I<Str>)

=item * B<sqlam> - low level SQL query builder (internal work horse, an instance of L<SQL::Abstract::More>)

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

Inserts rows into the database and returns the results as a I<DBI::st> statement
handle.

Please note that C<NULL> values will be converted to Perl C<undef>.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/insert>.

=head2 update

Updates rows in the database and returns the results as a I<DBI::st> statement
handle.

Please note that C<NULL> values will be converted to Perl C<undef>.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/update>.

=head2 merge

Either directly executes or emulates an SQL MERGE (you could also call it
REPLACE) function and returns the results as a I<DBI::st> statement handle.

Named parameters:

=over

=item * B<into> - Table name (I<Str>, required)

=item * B<set> - Columns that are always set (INSERT or UPDATE). Hash with
column name / value pairs.

Please note that C<undef> is interpreted as C<NULL> (I<HashRef>, required)

=item * B<set_once> - Columns that are only set on INSERT (additional to those
in the C<where> parameter. Hash with column name / value pairs.

Please note that C<undef> is interpreted as C<NULL> (I<HashRef>, required)

=item * B<where> - WHERE clause specification that must contain the PRIMARY KEY
columns and only allows "AND" and "equal" operators:
C<<{ col1 => val1, col2 => val2 }>> (I<HashRef>)

The values from the WHERE clause are also inserted if the row does not exist
(together with those from C<set_once>)!

=back

=head2 delete

Deletes rows in the database and returns the results as a I<DBI::st> statement
handle.

For parameters see L<OpenXPKI::Server::Database::QueryBuilder/delete>.

=head2 start_txn

Records the start of a new transaction (i.e. sets a flag) without database
interaction.

If the flag was already set (= another transaction is running), a C<ROLLBACK> is
performed first and an error message is logged.

Please note that after a C<fork()> the flag is be reset as the C<DBI> handle
is also reset (so there cannot be a running transaction).

=head2 in_txn

Returns C<true> if a transaction is currently running, i.e. after L</start_txn>
was called but before L</commit> or L</rollback> where called.

=head2 commit

Commits a transaction.

Logs an error if L</start_txn> was not called first.

=head2 rollback

Rolls back a transaction.

Logs an error if L</start_txn> was not called first.

=cut

################################################################################

=head1 Low level methods

The following methods allow more fine grained control over the query processing.

=head2 dbh

Returns a fork safe DBI handle. Connects to the database if neccessary.

To remain fork safe DO NOT CACHE this (also do not convert into a lazy attribute).

=head2 run

Executes the given query and returns a DBI statement handle.

    my $sth = $db->run($query) or die "Error executing query: $@";

Parameters:

=over

=item * B<$query> - query to run (either a I<OpenXPKI::Server::Database::Query>
or a literal SQL string)

=back

=head2 disconnect

Disconnects from the database. Might be useful to e.g. remove file locks when
using SQLite.

=cut

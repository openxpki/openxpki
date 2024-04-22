package OpenXPKI::Server::Database;
use OpenXPKI -class;

=head1 Name

OpenXPKI::Server::Database - Handle database connections and encapsulate DB
specific drivers/functions.

=cut

# Core modules
use Math::BigInt;
use Module::Load;

# CPAN modules
use DBIx::Handler;
use DBI::Const::GetInfoType; # provides %GetInfoType hash
use SQL::Abstract::More;

# Project modules
use OpenXPKI::Server::Database::Role::Driver;
use OpenXPKI::Server::Database::QueryBuilder;
use OpenXPKI::Server::Database::Query;

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

# the OpenXPKI version index of the database schema
# based on the value stored in the datapool
# this might NOT work on dedicated logger handles
has 'version' => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->select_value(
            from => 'datapool',
            columns => [ 'datapool_value' ],
            where => {
                pki_realm => '',
                namespace => 'config',
                datapool_key => 'dbschema',
        }) // 0;
    }
);

has 'log' => (
    is => 'ro',
    isa => 'Object',
    required => 1,
);

# Parameters to construct DSN, mostly from config: system.database.[main|log]
has 'db_params' => (
    is => 'ro',
    isa => 'HashRef',
    required => 1,
);

has 'autocommit' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
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
            driver => $self->driver,
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
            $self->_driver_return_val_to_hash(
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

    # Remove undefined value (= empty option in originating config file)
    for (keys %args) {
        delete $args{$_} unless defined $args{$_};
    }

    my $driver = $args{type};
    OpenXPKI::Exception->throw (
        message => "Parameter 'type' missing: it must equal the last part of a package in the OpenXPKI::Server::Database::Driver::* namespace.",
    ) unless $driver;
    delete $args{type};

    my $class = "OpenXPKI::Server::Database::Driver::".$driver;
    ##! 32: "Trying to load driver class " . $class;

    eval { Module::Load::load($class) };
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

# Converts DBI errors into OpenXPKI exceptions
sub _dbi_error_handler {
    my ($self, $msg, $dbh, $more_details) = @_;

    my $details = {
        source => "?",
        dbi_error => $dbh->errstr,
        dsn => $self->driver->dbi_dsn,
        user => $self->driver->user,
        ref $more_details ? %$more_details : (),
    };

    my $method = "";
    my $our_msg;

    # original message is like: [class] [method] failed: [message]
    if ($msg =~ m/^(?<class>[a-z:_]+)\s+(?<method>[^\(\s]+)/i) {
        $details->{source} = sprintf("%s::%s", $+{class}, $+{method});
        $method = $+{method};
    }

    $our_msg = "connection failed"                          if "connect" eq $method;
    $our_msg = "preparing SQL query failed"                 if "prepare" eq $method;
    $our_msg = "binding parameters to SQL statement failed" if "bind_params" eq $method;
    $our_msg = "execution of SQL query failed"              if "execute" eq $method;

    OpenXPKI::Exception->throw(
        message => "Database error" . ($our_msg ? ": $our_msg" : ""),
        params => $details,
    );
};

sub _build_dbix_handler {
    my $self = shift;
    ##! 4: "DSN: ".$self->driver->dbi_dsn
    ##! 4: "User: ".($self->driver->user // '(none)')
    my %params = $self->_driver_return_val_to_hash(
        [ $self->driver->dbi_connect_params ], # driver might return a list so we enforce list context
        ref($self->driver)."::dbi_connect_params",
    );
    ##! 4: "Additional connect() attributes: " . join " | ", map { $_." = ".$params{$_} } keys %params

    my %params_from_config;
    if ($self->db_params->{driver} && ref $self->db_params->{driver} eq 'HASH') {
        %params_from_config = %{$self->db_params->{driver}};
    }

    my $dbix = DBIx::Handler->new(
        $self->driver->dbi_dsn,
        $self->driver->user,
        $self->driver->passwd,
        {
            AutoCommit => $self->autocommit,
            LongReadLen => 10_000_000,
            RaiseError => 0,
            PrintError => 0,
            HandleError => sub {
                my ($msg, $dbh, $retval) = @_;
                # avoid access to $self during global destruction (might be undef then)
                if (${^GLOBAL_PHASE} eq "DESTRUCT") {
                    warn "$msg [pid=$$]\n";
                } else {
                    $self->_dbi_error_handler($msg, $dbh);
                }
            },
            # AutoInactiveDestroy => 1, -- automatically set by DBIx::Handler
            %params,
            %params_from_config,
        },
        {
            on_connect_do => sub {
                my $dbh = shift;
                ##! 32: 'DBMS version: ' . $dbh->get_info($GetInfoType{SQL_DBMS_VER});
                # custom on_connect actions
                $self->driver->on_connect($dbh);
                # on_connect_do is (also) called after fork():
                # then we get a new DBI handle and a previous transaction is invalid.
                # So we check the PID here and clear the old transaction if it differs.
                $self->_clear_txn_starter if ($self->in_txn and $self->_txn_starter->[3] != $$);
            },
        }
    );

    $self->driver->perform_checks($dbix->dbh);

    ##! 32: 'DBIx Handle ' . Dumper $dbix

    return $dbix;
}

################################################################################
# Methods
#

sub _driver_return_val_to_hash {
    my ($self, $params, $method) = @_;
    my $normalized;
    if (scalar @$params == 0) {             # undef
        $normalized = {};
    }
    elsif (scalar @$params > 1) {           # list
        $normalized = { @$params };
    }
    elsif (ref $params->[0] eq 'HASH') {    # HashRef
        $normalized = $params->[0];
    }
    else {
        OpenXPKI::Exception->throw (
            message => "Faulty driver implementation: '$method' did not return undef, a HashRef or a plain hash (list)",
        );
    }
    return %$normalized;
}

sub _driver_return_val_to_list {
    my ($self, $params, $method) = @_;
    my $normalized;
    if (scalar @$params == 0) {             # undef
        $normalized = [];
    }
    elsif (ref $params->[0] eq 'ARRAY') {   # ArrayRef
        $normalized = $params->[0];
    }
    elsif (scalar(grep { /.+/ } map { ref } @$params) > 0) { # some elements are not scalars
        OpenXPKI::Exception->throw (
            message => "Faulty driver implementation: '$method' did not return undef, an ArrayRef or a plain list",
        );
    }
    else {                                  # list of scalars (or single scalar)
        $normalized = [ @$params ];
    }
    return @$normalized;
}

# To remain fork safe DO NOT CACHE this (also do not convert into a lazy attribute).
sub dbh {
    my $self = shift;
    # If this is too slow due to DB pings, we could pass "no_ping" attribute to
    # DBIx::Handler and copy the "fixup" code from DBIx::Connector::_fixup_run()
    my $dbh = $self->_dbix_handler->dbh;     # fork-safe DBI handle
    $dbh->{FetchHashKeyName} = 'NAME_lc';    # enforce lowercase names
    return $dbh;
}

sub ping {
    my $self = shift;
    return $self->_dbix_handler->dbh->ping();
}

# Execute given query
signature_for run => (
    method => 1,
    positional => [
        'OpenXPKI::Server::Database::Query | Str',
        'Optional[ Bool ]', { default => 0 },
    ],
);
sub run ($self, $query, $return_rownum) {
    my $query_string;
    my $query_params;
    if (ref $query) {
        $query_string = $query->string;
        $query_params = $query->params;
    }
    else {
        $query_string = $query;
    }

    # pass extra info about $query_string to our error handler
    local $self->dbh->{HandleError} = sub {
        my ($msg, $dbh, $retval) = @_;
        $self->_dbi_error_handler($msg, $dbh, { query => $query_string });
    };

    ##! 16: "Query: " . $query_string;
    my $sth = $self->dbh->prepare($query_string);
    # bind parameters via SQL::Abstract::More to do some magic
    $self->sqlam->bind_params($sth, @{$query_params}) if $query_params;

    $self->log->trace(sprintf "DB query: %s", $query_string) if $self->log->is_trace;

    my $rownum = $sth->execute;
    ##! 16: "$rownum rows affected"

    return $return_rownum ? $rownum : $sth;
}

# SELECT
# Returns: DBI statement handle
sub select {
    my $self = shift;
    my $query = $self->query_builder->select(@_);
    return $self->run($query);
}

# SELECT - return first row
# Returns: HashRef
sub select_one {
    my $self = shift;
    return $self->select(@_, limit => 1)->fetchrow_hashref;
}

# SELECT - return first column from first row
# Returns: Scalar
sub select_value {
    my $self = shift;
    my $row = $self->select(@_, limit => 1)->fetchrow_arrayref;
    return unless ($row);
    return $row->[0];
}

# SELECT - return first column from all rows
# Returns: ArrayRef[Scalar]
sub select_column {
    my $self = shift;
    my $result = $self->select(@_)->fetchall_arrayref([]);
    return [ map { $_->[0] } @$result ];
}

# SELECT - return all rows as list of arrays
# Returns: ArrayRef[ArrayRef]
sub select_arrays {
    my $self = shift;
    return $self->select(@_)->fetchall_arrayref([]);
}

# SELECT - return all rows as list of hashes
# Returns: ArrayRef[HashRef]
sub select_hashes {
    my $self = shift;
    return $self->select(@_)->fetchall_arrayref({});
}

# SUB SELECT
# Returns: reference (!) to an ArrayRef that has to be included into the query
sub subselect {
    my $self = shift;
    return $self->query_builder->subselect(@_);
}

sub count {
    my $self = shift;
    my %query_param = @_;

    for (qw(order_by limit offset)) {
        delete $query_param{$_} if defined $query_param{$_};
    }

    return $self->driver->count_rows($self, $self->query_builder->select(%query_param) );
}

# INSERT
# Returns: DBI statement handle
signature_for insert => (
    method => 1,
    named => [
        into     => 'Str',
        values   => 'HashRef',
    ],
    bless => !!0, # return a HashRef instead of an Object
);
sub insert ($self, $arg) {
    # Replace AUTO_ID with value of next_id()
    for (keys %{ $arg->{values} }) {
        $arg->{values}->{$_} = $self->next_id($arg->{into})
            if (ref $arg->{values}->{$_} eq "OpenXPKI::Server::Database::AUTOINCREMENT"); # ::AUTOINCREMENT is a "virtual" package
    }

    my $query = $self->query_builder->insert($arg->%*);
    return $self->run($query, 1); # 1 = return number of affected rows
}

# UPDATE
# Returns: DBI statement handle
sub update {
    my $self = shift;
    my $query = $self->query_builder->update(@_);
    return $self->run($query, 1); # 1 = return number of affected rows
}

# MERGE
# Returns: DBI statement handle
signature_for merge => (
    method => 1,
    named => [
        into     => 'Str',
        set      => 'HashRef',
        set_once => 'Optional[ HashRef ]', { default => {} },
        # The WHERE specification contains the primary key columns.
        # In case of an INSERT these will be used as normal values. Therefore
        # we only allow scalars as hash values (which are translated to AND
        # connected "equals" conditions by SQL::Abstract::More).
        where    => 'HashRef[Value]',
    ],
);
sub merge ($self, $arg) {
    my $query = $self->driver->merge_query(
        $self,
        $self->query_builder->_add_namespace_to($arg->into),
        $arg->set,
        $arg->set_once,
        $arg->where,
    );
    return $self->run($query, 1); # 1 = return number of affected rows
}

# DELETE
# Returns: DBI statement handle
sub delete {
    my $self = shift;
    my $query = $self->query_builder->delete(@_);
    return $self->run($query, 1); # 1 = return number of affected rows
}

#
sub _run_and_commit {
    my ($self, $method, @args) = @_;
    $self->start_txn unless $self->autocommit;
    my $result = $self->$method(@args);
    $self->commit unless $self->autocommit;
    return $result;
}

#
sub insert_and_commit { shift->_run_and_commit("insert", @_); }
sub update_and_commit { shift->_run_and_commit("update", @_); }
sub merge_and_commit  { shift->_run_and_commit("merge",  @_); }
sub delete_and_commit { shift->_run_and_commit("delete", @_); }

# Create a new insert ID ("serial")
sub next_id {
    my ($self, $table) = @_;

    # get new serial number from DBMS (SQL sequence or emulation via table)

    my $seq_table = $self->query_builder->_add_namespace_to("seq_$table");
    my $id_int = $self->driver->next_id($self, $seq_table );
    my $id = Math::BigInt->new($id_int);
    ##! 32: 'Next ID: ' . $id->bstr()

    # shift bitwise left and add server id (default: 255)
    my $nodeid_bits = $self->db_params->{server_shift} // 8;
    my $nodeid      = $self->db_params->{server_id} // 2 ** $nodeid_bits - 1;
    $id->blsft($nodeid_bits);
    $id->bior(Math::BigInt->new($nodeid));

    ##! 32: 'Next ID - after bitshift: ' . $id->bstr()
    return $id->bstr();
}

# Create a new sequence
sub create_sequence {
    my ($self, $table) = @_;
    my $seq_table = $self->query_builder->_add_namespace_to("seq_$table");
    my $query = $self->driver->sequence_create_query($self, $seq_table);
    return $self->run($query, 0);
}

# Drop a sequence
sub drop_sequence {
    my ($self, $table) = @_;
    my $seq_table = $self->query_builder->_add_namespace_to("seq_$table");
    my $query = $self->driver->sequence_drop_query($self, $seq_table);
    return $self->run($query, 0);
}

# Drop a table
sub drop_table {
    my ($self, $table) = @_;
    my $query = $self->driver->table_drop_query($self, $self->query_builder->_add_namespace_to($table));
    return $self->run($query, 0);
}

sub start_txn {
    my $self = shift;
    return $self->log->warn("AutoCommit is on, start_txn() is useless")
      if $self->autocommit;

    my $caller = [ caller, $$ ];
    if ($self->in_txn) {
        $self->log->debug(
            sprintf "transaction start requested during a running transaction (started in %s:%i) in %s:%i",
                $caller->[0],
                $caller->[2],
                $self->_txn_starter->[0],
                $self->_txn_starter->[2],
        ) if $self->log->is_debug;
    }
    ##! 16: "Transaction start"
    $self->_txn_starter($caller);

    $self->log->trace(sprintf "transaction start in %s:%i", $caller->[0], $caller->[2])
      if $self->log->is_trace;
}

sub commit {
    my $self = shift;
    return $self->log->warn("AutoCommit is on, commit() is useless")
      if $self->autocommit;

    my $caller = [ caller ];
    if ($self->in_txn) {
        $self->log->trace(
            sprintf "commit for txn (started at %s:%i) in %s:%i",
                $self->_txn_starter->[0], $self->_txn_starter->[2],
                $caller->[0], $caller->[2]
        ) if $self->log->is_trace;
    }
    else {
        $self->log->debug(
            sprintf "commit was requested without prior transaction start in %s:%i",
                $caller->[0], $caller->[2]
        ) if $self->log->is_debug;
    }

    ##! 16: "Commit"
    $self->dbh->commit;
    $self->_clear_txn_starter;
}

sub rollback {
    my $self = shift;
    return $self->log->warn("AutoCommit is on, rollback() is useless") if $self->autocommit;

    my $caller = [ caller ];

    if ($self->in_txn) {
        if ($self->log->is_trace) {
            $self->log->trace(
                sprintf "rollback for txn (started at %s:%i) in %s:%i",
                    $self->_txn_starter->[0], $self->_txn_starter->[2],
                    $caller->[0], $caller->[2]
            ) if $self->log->is_trace;
        }
    }
    else {
        $self->log->debug(
            sprintf "rollback was requested without prior transaction start in %s:%i",
                $caller->[0], $caller->[2]
        ) if $self->log->is_debug;
    }

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
         .    .------------------------------.
         ....>| O:S:D::Role::CountEmulation  |
         .    '------------------------------'
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
string (required).

Required keys in this hash:

=over

=item * B<type> - last part of a package in the C<OpenXPKI::Server::Database::Driver::*> namespace. (I<Str>, required)

=item * Any of the L<OpenXPKI::Server::Database::Role::Driver/Constructor parameters>

=item * Additional parameters required by the specific driver

=back

=item * B<autocommit> - I<Bool> to switch on L<DBI/AutoCommit> (optional, default: 0)

=back

=head2 Others

=over

=item * B<driver> - database specific driver instance (consumer of L<OpenXPKI::Server::Database::Role::Driver>)

=item * B<query_builder> - OpenXPKI query builder to create abstract SQL queries (L<OpenXPKI::Server::Database::QueryBuilder>)

Usage:

    # returns an OpenXPKI::Server::Database::Query object
    my $query = $db->query_builder->select(
        from => 'certificate',
        columns  => [ 'identifier' ],
        where => { pki_realm => 'democa' },
    );

=item * B<db_version> - database version, equals the result of C<$dbh-E<gt>get_version(...)> (I<Str>)

=item * B<sqlam> - low level SQL query builder (internal work horse, an instance of L<SQL::Abstract::More>)

=back

=head1 Methods

Note: all methods might throw an L<OpenXPKI::Exception> if there are errors in the query or during it's execution.

=head2 new

Constructor.

Named parameters: see L<attributes section above|/"Constructor parameters">.



=head2 select

Selects rows from the database and returns the results as a I<DBI::st> statement
handle.

Please note that C<NULL> values will be converted to Perl C<undef>.

Subqueries can be realized using L</subselect>.

Named parameters:

=over

=item * B<columns> - List of column names (I<ArrayRef[Str]>, required)

=item * B<from> - Table name (or list of) (I<Str | ArrayRef[Str]>, required)

=item * B<from_join> - A B<string> to describe table relations for I<FROM .. JOIN> following the spec in L<SQL::Abstract::More/join> (I<Str>)

    from_join => "certificate  req_key=req_key  csr"

Please note that you cannot specify C<from> and C<from_join> at the same time.

=item * B<where> - I<WHERE> clause following the spec in L<SQL::Abstract/WHERE-CLAUSES>. A literal query can be defined using a ScalarRef: C<where =E<gt> \"id E<gt>= 3"> (I<ScalarRef | ArrayRef | HashRef>)

=item * B<group_by> - I<GROUP BY> column (or list of) (I<Str | ArrayRef>)

=item * B<having> - I<HAVING> clause following the spec in L<SQL::Abstract/WHERE-CLAUSES> (I<Str | ArrayRef | HashRef>)

=item * B<order_by> - Plain I<ORDER BY> string or list of columns. Each column name can be preceded by a "-" for descending sort (I<Str | ArrayRef>)

=item * B<limit> - (I<Int>)

=item * B<offset> - (I<Int>)

=back



=head2 subselect

Builds a subquery to be used within another query and returns a reference to an I<ArrayRef>.

The returned structure is understood by L<SQL::Abstract|SQL::Abstract/Literal_SQL_with_placeholders_and_bind_values_(subqueries)> which is used internally.

E.g. to create the following query:

    SELECT title FROM books
    WHERE (
        author_id IN (
            SELECT id FROM authors
            WHERE ( legs > 2 )
        )
    )

you can use C<subselect()> as follows:

    CTX('dbi')->select(
        from => "books",
        columns => [ "title" ],
        where => {
            author_id => CTX('dbi')->subselect("IN" => {
                from => "authors",
                columns => [ "id" ],
                where => { legs => { '>' => 2 } },
            }),
        },
    );

Positional parameters:

=over

=item * B<$operator> - SQL operator between column and subquery (I<Str>, required).

Operators can be e.g. C<'IN'>, C<'NOT IN'>, C<'E<gt> MAX'> or C<'E<lt> ALL'>.

=item * B<$query> - The query parameters in a I<HashRef> as they would be given to L</select> (I<HashRef>, required)

=back

=head2 select_value

Selects one row from the database and returns the content of the first
column.

For parameters see L</select>.

Returns C<undef> if the query had no results.

Please note that C<NULL> values will be converted to Perl C<undef>.


=head2 select_column

Selects the first column from all rows in the result set and return
them as ArrayRef.

For parameters see L</select>.

Returns an empty list if the query had no results.

Please note that C<NULL> values will be converted to Perl C<undef>.

=head2 select_one

Selects one row from the database and returns the results as a I<HashRef>
(column name => value) by calling C<$sth-E<gt>fetchrow_hashref>.

For parameters see L</select>.

Returns C<undef> if the query had no results.

Please note that C<NULL> values will be converted to Perl C<undef>.



=head2 select_arrays

Selects all rows from the database and returns them as an I<ArrayRef[ArrayRef]>.
This is a shortcut to C<$dbi-E<gt>select(...)-E<gt>fetchall_arrayref([])>.

For parameters see L</select>.

Please note that C<NULL> values will be converted to Perl C<undef>.



=head2 select_hashes

Selects all rows from the database and returns them as an I<ArrayRef[HashRef]>.
This is a shortcut to C<$dbi-E<gt>select(...)-E<gt>fetchall_arrayref({})>.

For parameters see L</select>.

Please note that C<NULL> values will be converted to Perl C<undef>.



=head2 count

Takes the same arguments as L</select>, wraps them into a subquery and
return the number of rows the select would return. The parameters
C<order_by>, C<limit> and C<offset> are ignored.



=head2 insert

Inserts rows into the database and returns the number of affected rows.

    $db->insert(
        into => "certificate",
        values => {
            identifier => AUTO_ID, # use the sequence associated with this table
            cert_key => $key,
            ...
        }
    );

B<AUTO_ID>: to automatically set a primary key to the next serial number (i.e. sequence
associated with this table) set it to C<AUTO_ID>. The C<AUTO_ID> subroutine is provided
by C<use OpenXPKI> or C<use OpenXPKI::Util>.

Named parameters:

=over

=item * B<into> - Table name (I<Str>, required)

=item * B<values> - Hash with column name / value pairs. Please note that
C<undef> is interpreted as C<NULL> (I<HashRef>, required).

=back



=head2 update

Updates rows in the database and returns the number of affected rows.

A I<WHERE> clause is required to prevent accidential updates of all rows in a table.

Please note that C<NULL> values will be converted to Perl C<undef>.

Named parameters:

=over

=item * B<table> - Table name (I<Str>, required)

=item * B<set> - Hash with column name / value pairs. Please note that C<undef> is interpreted as C<NULL> (I<HashRef>, required)

=item * B<where> - I<WHERE> clause following the spec in L<SQL::Abstract/WHERE-CLAUSES>. A literal query can be defined using a ScalarRef: C<where =E<gt> \"id E<gt>= 3"> (I<ScalarRef | ArrayRef | HashRef>)

=back



=head2 merge

Either directly executes or emulates an SQL I<MERGE> (you could also call it
I<REPLACE>) function and returns the number of affected rows.

Please note that e.g. MySQL returns 2 (not 1) if an update was performed. So
you should only use the return value to test for 0 / FALSE.

Named parameters:

=over

=item * B<into> - Table name (I<Str>, required)

=item * B<set> - Columns that are always set (I<INSERT> or I<UPDATE>). Hash with
column name / value pairs.

Please note that C<undef> is interpreted as C<NULL> (I<HashRef>, required)

=item * B<set_once> - Columns that are only set on I<INSERT> (additional to those
in the C<where> parameter. Hash with column name / value pairs.

Please note that C<undef> is interpreted as C<NULL> (I<HashRef>, required)

=item * B<where> - I<WHERE> clause specification that must contain the I<PRIMARY KEY>
columns and only allows I<AND> and I<equal> operators:
C<{ col1 =E<gt> val1, col2 =E<gt> val2 }> (I<HashRef>)

The values from the I<WHERE> clause are also inserted if the row does not exist
(together with those from C<set_once>)!

=back



=head2 delete

Deletes rows in the database and returns the results as a I<DBI::st> statement
handle.

To prevent accidential deletion of all rows of a table you must specify
parameter C<all> if you want to do that:

    CTX('dbi')->delete(
        from => "mytab",
        all => 1,
    );

Named parameters:

=over

=item * B<from> - Table name (I<Str>, required)

=item * B<where> - I<WHERE> clause following the spec in L<SQL::Abstract/WHERE-CLAUSES>. A literal query can be defined using a ScalarRef: C<where =E<gt> \"id E<gt>= 3"> (I<ScalarRef | ArrayRef | HashRef>)

=item * B<all> - Set this to 1 instead of specifying C<where> to delete all rows (I<Bool>)

=back



=head2 start_txn

Records the start of a new transaction (i.e. sets a flag) without database
interaction.

If the flag was already set (= another transaction is running), nothing happens
but a debug message is logged.

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

=head2 insert_and_commit

Calling this method is the same as:

    $db->start_txn;
    $db->insert(...);
    $db->commit;

For more informations see L<OpenXPKI::Server::Database/insert>.

=head2 update_and_commit

Calling this method is the same as:

    $db->start_txn;
    $db->update(...);
    $db->commit;

For more informations see L<OpenXPKI::Server::Database/update>.

=head2 merge_and_commit

Calling this method is the same as:

    $db->start_txn;
    $db->merge(...);
    $db->commit;

For more informations see L<OpenXPKI::Server::Database/merge>.

=head2 delete_and_commit

Calling this method is the same as:

    $db->start_txn;
    $db->delete(...);
    $db->commit;

For more informations see L<OpenXPKI::Server::Database/delete>.

=cut

################################################################################

=head1 Low level methods

The following methods allow more fine grained control over the query processing.

=head2 dbh

Returns a fork safe DBI handle. Connects to the database if neccessary.

To remain fork safe DO NOT CACHE this (also do not convert into a lazy attribute).

=head2 run

Executes the given query and returns a DBI statement handle. Throws an exception
in case of errors.

    my $sth;
    eval {
        $sth = $db->run($query);
    };
    if (my $e = OpenXPKI::Exception->caught) {
        die "OpenXPKI exception executing query: $e";
    }
    elsif ($@) {
        die "Unknown error: $e";
    };

Parameters:

=over

=item * B<$query> - query to run (either a I<OpenXPKI::Server::Database::Query>
or a literal SQL string)

=item * B<$return_rownum> - return number of affected rows instead of DBI
statement handle (optional, default: 0).

If no rows were affected, then "0E0" is returned which Perl will treat as 0 but
will regard as true.

=back

=head2 disconnect

Disconnects from the database. Might be useful to e.g. remove file locks when
using SQLite.

=cut

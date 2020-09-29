use utf8;

package DatabaseTest::Connection;
use Moose;

use Test::More;

# internal test database type name
has 'type' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'dbi_params' => (
    is => 'rw',
    isa => 'HashRef',
    required => 1,
);

has 'dbi' => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Database',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Server::Database->new(
            log => $self->_log,
            db_params => $self->dbi_params,
        );
    },
);

has 'columns' => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 1,
);

has '_col_info' => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        my @names;
        my @fulldef;
        for (my $i=0; $i<scalar(@{$self->columns}); $i+=2) {
            my $col = $self->columns->[$i];
            my $def = $self->columns->[$i+1];
            push @names, $col;
            push @fulldef, "$col $def";
        }
        return {
            names => \@names,
            fulldef => \@fulldef,
        };
    },
);

has 'data' => (
    is => 'rw',
    isa => 'ArrayRef',
    predicate => 'has_data',
);

has '_log' => (
    is => 'rw',
    isa => 'Object',
);

sub BUILD {
    my $self = shift;
    Log::Log4perl->init(\"
        log4perl.rootLogger = DEBUG, Everything
        log4perl.appender.Everything          = Log::Log4perl::Appender::String
        log4perl.appender.Everything.layout   = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Everything.layout.ConversionPattern = %d %c.%p %m%n
    ");
    $self->_log( Log::Log4perl->get_logger() );
}

sub get_data {
    my $self = shift;
    my $sth = $self->dbi->select(from => "test", columns => $self->_col_info->{names});
    return $sth->fetchall_arrayref;
}

sub clear_data {
    my $self = shift;
    BAIL_OUT("Cannot re-init data because attribute 'data' was not set") unless $self->has_data;
    note "Clearing test data";
    $self->_drop_table;
    $self->_create_table;
}

# Returns all log messages since the last call of this method
sub get_log {
    my $appender = Log::Log4perl->appender_by_name("Everything")
        or BAIL_OUT("Could not access Log4perl appender");
    my $messages = $appender->string;
    $appender->string("");
    return $messages;
}

sub _create_table {
    my $self = shift;
    eval { $self->dbi->drop_table("test") }; # FIXME Remove eval{} as soon as Oracle and DB2 driver don't throw exception on non-existing table
    diag $@ if $@;
    $self->dbi->run("CREATE TABLE test (".join(", ", @{ $self->_col_info->{fulldef} }).")");
    # Create a hash with the column names and the data
    my $col_names = $self->_col_info->{names};
    for my $row (@{ $self->data }) {
        my %values = map { $col_names->[$_] => $row->[$_] } 0..$#{ $col_names };
        $self->dbi->insert(into => "test", values => \%values);
    }

    eval { $self->dbi->drop_sequence("test") }; # FIXME Remove eval{} as soon as Oracle and DB2 driver don't throw exception on non-existing table
    diag $@ if $@;
    $self->dbi->create_sequence("test");

    $self->dbi->run("COMMIT");
}

sub _drop_table {
    my $self = shift;
    $self->dbi->drop_table("test");
    $self->dbi->drop_sequence("test");
    $self->dbi->run("COMMIT");
}

################################################################################
################################################################################
################################################################################

package DatabaseTest;
use Moose;

use Test::More;
use Test::Exception;
use OpenXPKI::MooseParams;
use Log::Log4perl;
use Moose::Util::TypeConstraints;


has 'columns' => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 1,
);
# if not set: do not create table / insert data
# (useful for parallel instances of DatabaseTest used to check things)
has 'data' => (
    is => 'rw',
    isa => 'ArrayRef',
    predicate => 'has_data',
);

enum 'DBMS', [qw( sqlite mysql mariadb oracle )];

# restrict tests to certain dbms
has 'test_only' => (
    is => 'rw',
    isa => 'ArrayRef[DBMS]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        test_all_dbs => 'is_empty',
        _test_db => 'first',
    },
);

# if not set: use SQLite in-memory DB
has 'sqlite_db' => (
    is => 'rw',
    isa => 'Str',
);

has 'test_no' => (
    is => 'rw',
    isa => 'Num',
    traits => ['Counter'],
    default => 0,
    init_arg => undef,
    handles => {
        count_test => 'inc',
    },
);



sub BUILD {
    my $self = shift;
    use_ok "OpenXPKI::Server::Database"; $self->count_test;
}

# Return true if the given DB type shall be tested
sub shall_test {
    my ($self, $dbtype) = @_;
    return ($self->test_all_dbs or $self->_test_db(sub {/^\Q$dbtype\E$/}));
}

# Run the given tests against all available DBMS
sub run {
    my ($self, $name, $plan, $tests) = positional_args(\@_,
        { isa => 'Str'},
        { isa => 'Int'},
        { isa => 'CodeRef' },
    );

    # creates and executes subtests
    my $SUBTEST = sub {
        my ($dbtype, $dbi_driver, $env_var, $dbi_params, $testname) = @_;

        return note "$env_var not set" if ($env_var and not $ENV{$env_var});
        return note "'$dbtype' test disabled" unless $self->shall_test($dbtype);
        return note "$dbi_driver is not installed" unless eval "require $dbi_driver";

        $self->count_test;
        # the actual test sub
        subtest $testname => sub {
            plan tests => $plan + 2;
            my $connection;
            lives_ok {
                $connection = DatabaseTest::Connection->new(
                    type => $dbtype,
                    dbi_params => $dbi_params,
                    columns => $self->columns,
                    $self->has_data ? (data => $self->data) : (),
                );
            } $dbi_params->{type}.": create Database instance";

SKIP: {
            skip "no 'data' given", 1 unless $self->has_data;
            lives_ok {
                $connection->_create_table;
            } $dbi_params->{type}.": insert test data";
}

            $tests->($connection);
            $connection->_drop_table if $self->has_data;
            # esp. prevent prevent deadlocks due to SQLite file locking if second instance of DatabaseTest is used later on:
            $connection->dbi->disconnect;
        };
    };

    # SQLite - runs always
    my $sqlite_db = $self->sqlite_db || ":memory:";
    $SUBTEST->('sqlite', 'DBD::SQLite', '', {
        type => "SQLite",
        name => $sqlite_db,
    }, "$name (SQLite '$sqlite_db')");

    # Oracle - runs if OXI_TEST_DB_ORACLE_NAME is set
    $SUBTEST->('oracle', 'DBD::Oracle', 'OXI_TEST_DB_ORACLE_NAME', {
        type => "Oracle",
        name => $ENV{OXI_TEST_DB_ORACLE_NAME},
        user => $ENV{OXI_TEST_DB_ORACLE_USER},
        passwd => $ENV{OXI_TEST_DB_ORACLE_PASSWORD},
    }, "$name (Oracle)");

    # MySQL - runs if OXI_TEST_DB_MYSQL_NAME is set
    my %mysql_params = (
        # if not specified, the driver tries socket connection
        $ENV{OXI_TEST_DB_MYSQL_DBHOST} ? ( host => $ENV{OXI_TEST_DB_MYSQL_DBHOST} ) : (),
        $ENV{OXI_TEST_DB_MYSQL_DBPORT} ? ( port => $ENV{OXI_TEST_DB_MYSQL_DBPORT} ) : (),
        name => $ENV{OXI_TEST_DB_MYSQL_NAME},
        user => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
    );
    $SUBTEST->('mysql', 'DBD::mysql', 'OXI_TEST_DB_MYSQL_NAME', {
        type => "MySQL",
        %mysql_params,
    }, "$name (MySQL)");

    # MariaDB - runs if OXI_TEST_DB_MYSQL_NAME is set
    $SUBTEST->('mariadb', 'DBD::mysql', 'OXI_TEST_DB_MYSQL_NAME', {
        type => "MariaDB",
        %mysql_params,
    }, "$name (MariaDB)");
}

__PACKAGE__->meta->make_immutable;

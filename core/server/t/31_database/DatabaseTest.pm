package DatabaseTest;
use Moose;

use Test::More;
use Test::Exception;
use OpenXPKI::MooseParams;
use Log::Log4perl;
use Moose::Util::TypeConstraints;

use FindBin qw( $Bin );
require "$Bin/DatabaseTestConnection.pm";


has 'columns' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

# if not set: do not create table / insert data
# (useful for parallel instances of DatabaseTest used to check things)
has 'data' => (
    is => 'rw',
    isa => 'ArrayRef',
    predicate => 'has_data',
);

enum 'DBMS', [qw( sqlite mysql mariadb oracle postgres )];

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

sub get_dbi_params {
    my ($self, $db_type) = positional_args(\@_,
        { isa => 'DBMS' },
    );

    if ('sqlite' eq $db_type) {
        return {
            type => "SQLite",
            name => ($self->sqlite_db || ":memory:"),
        }
    }

    if ('oracle' eq $db_type) {
        return {
            type => "Oracle",
            name => $ENV{OXI_TEST_DB_ORACLE_NAME},
            user => $ENV{OXI_TEST_DB_ORACLE_USER},
            passwd => $ENV{OXI_TEST_DB_ORACLE_PASSWORD},
        }
    }

    my %mysql_params = (
        # if not specified, the driver tries socket connection
        $ENV{OXI_TEST_DB_MYSQL_DBHOST} ? ( host => $ENV{OXI_TEST_DB_MYSQL_DBHOST} ) : (),
        $ENV{OXI_TEST_DB_MYSQL_DBPORT} ? ( port => $ENV{OXI_TEST_DB_MYSQL_DBPORT} ) : (),
        name => $ENV{OXI_TEST_DB_MYSQL_NAME},
        user => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
    );

    if ('mysql' eq $db_type) {
        return {
            type => "MySQL",
            %mysql_params,
        }
    }

    if ('mariadb' eq $db_type) {
        return {
            type => "MariaDB",
            %mysql_params,
        }
    }

    if ('postgres' eq $db_type) {
        return {
            type => "PostgreSQL",
            $ENV{OXI_TEST_DB_POSTGRES_DBHOST} ? ( host => $ENV{OXI_TEST_DB_POSTGRES_DBHOST} ) : (),
            $ENV{OXI_TEST_DB_POSTGRES_DBPORT} ? ( port => $ENV{OXI_TEST_DB_POSTGRES_DBPORT} ) : (),
            name => $ENV{OXI_TEST_DB_POSTGRES_NAME},
            user => $ENV{OXI_TEST_DB_POSTGRES_USER},
            passwd => $ENV{OXI_TEST_DB_POSTGRES_PASSWORD},
        }
    }
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
        my ($dbtype, $dbi_driver, $env_var, $testname) = @_;

        return note "$env_var not set" if ($env_var and not $ENV{$env_var});
        return note "'$dbtype' test disabled" unless $self->shall_test($dbtype);
        return note "$dbi_driver is not installed" unless eval "require $dbi_driver";

        my $dbi_params = $self->get_dbi_params($dbtype);

        $self->count_test;
        # the actual test sub
        subtest $testname => sub {
            plan tests => $plan + 2;
            my $connection;
            lives_ok {
                $connection = DatabaseTestConnection->new(
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

    $SUBTEST->('sqlite',   'DBD::SQLite', undef,                       "$name (SQLite)");
    $SUBTEST->('oracle',   'DBD::Oracle', 'OXI_TEST_DB_ORACLE_NAME',   "$name (Oracle)");
    $SUBTEST->('mysql',    'DBD::mysql',  'OXI_TEST_DB_MYSQL_NAME',    "$name (MySQL)");
    $SUBTEST->('mariadb',  'DBD::mysql',  'OXI_TEST_DB_MYSQL_NAME',    "$name (MariaDB)");
    $SUBTEST->('postgres', 'DBD::Pg',     'OXI_TEST_DB_POSTGRES_NAME', "$name (PostgreSQL)");
}

__PACKAGE__->meta->make_immutable;

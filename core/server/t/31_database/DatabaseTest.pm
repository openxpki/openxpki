package DatabaseTest;
use Moose;

use Test::More;
use Test::Exception;
use Log::Log4perl;
use Moose::Util::TypeConstraints; # PLEASE NOTE: this enables all warnings via Moose::Exporter
use Type::Params qw( signature_for );

use FindBin qw( $Bin );
require "$Bin/DatabaseTestConnection.pm";

# should be done after imports to safely disable warnings in Perl < 5.36
use experimental 'signatures';

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

enum 'DBMS', [qw( SQLite MySQL MariaDB MariaDB2 Oracle PostgreSQL )];

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

signature_for get_dbi_params => (
    method => 1,
    positional => [ 'DBMS' ],
);
sub get_dbi_params ($self, $db_type) {
    my %common = (
        lock_timeout => 1,
    );

    if ('SQLite' eq $db_type) {
        return {
            type => $db_type,
            %common,
            name => ($self->sqlite_db || ":memory:"),
        }
    }

    if ('Oracle' eq $db_type) {
        return {
            type => $db_type,
            %common,
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

    if ('MySQL' eq $db_type or 'MariaDB' eq $db_type or 'MariaDB2' eq $db_type) {
        return {
            type => $db_type,
            %common,
            %mysql_params,
        }
    }

    if ('PostgreSQL' eq $db_type) {
        return {
            type => $db_type,
            %common,
            $ENV{OXI_TEST_DB_POSTGRES_DBHOST} ? ( host => $ENV{OXI_TEST_DB_POSTGRES_DBHOST} ) : (),
            $ENV{OXI_TEST_DB_POSTGRES_DBPORT} ? ( port => $ENV{OXI_TEST_DB_POSTGRES_DBPORT} ) : (),
            name => $ENV{OXI_TEST_DB_POSTGRES_NAME},
            user => $ENV{OXI_TEST_DB_POSTGRES_USER},
            passwd => $ENV{OXI_TEST_DB_POSTGRES_PASSWORD},
        }
    }
}

# Run the given tests against all available DBMS
signature_for run => (
    method => 1,
    positional => [ 'Str', 'Int', 'CodeRef' ],
);
sub run ($self, $name, $plan, $tests) {
    # creates and executes subtests
    my $SUBTEST = sub {
        my ($dbtype, $dbi_driver, $env_var, $testname) = @_;

        return note "$env_var not set" if ($env_var and not $ENV{$env_var});
        return unless $self->shall_test($dbtype);
        return note "$dbi_driver is not installed" unless eval "require $dbi_driver";

        my $dbi_params = $self->get_dbi_params($dbtype);

        $self->count_test;
        # the actual test sub
        subtest $testname => sub {
            plan tests => $plan + 2;
            my ($conn1, $conn2);
            lives_ok {
                $conn1 = DatabaseTestConnection->new(
                    type => $dbtype,
                    dbi_params => $dbi_params,
                    columns => $self->columns,
                    $self->has_data ? (data => $self->data) : (),
                );
                $conn2 = DatabaseTestConnection->new(
                    type => $dbtype,
                    dbi_params => $dbi_params,
                    columns => $self->columns,
                );
            } $dbi_params->{type}.": create Database instances";

            SKIP: {
                skip "no data provided to insert", 1 unless $self->has_data;
                lives_ok {
                    $conn1->_create_table;
                } $dbi_params->{type}.": insert test data";
            }

            $tests->($conn1, $conn2);
            $conn1->dbi->commit;
            $conn2->dbi->commit;
            $conn1->_drop_table if $self->has_data;
            # esp. prevent prevent deadlocks due to SQLite file locking if second instance of DatabaseTest is used later on:
            $conn1->dbi->disconnect;
            $conn2->dbi->disconnect;
        };
    };

    $SUBTEST->('SQLite',     'DBD::SQLite',  undef,                       "$name (SQLite)");
    $SUBTEST->('Oracle',     'DBD::Oracle',  'OXI_TEST_DB_ORACLE_NAME',   "$name (Oracle)");
    $SUBTEST->('MySQL',      'DBD::mysql',   'OXI_TEST_DB_MYSQL_NAME',    "$name (MySQL)");
    $SUBTEST->('MariaDB',    'DBD::mysql',   'OXI_TEST_DB_MYSQL_NAME',    "$name (MariaDB)");
    $SUBTEST->('MariaDB2',   'DBD::MariaDB', 'OXI_TEST_DB_MYSQL_NAME',    "$name (MariaDB2)");
    $SUBTEST->('PostgreSQL', 'DBD::Pg',      'OXI_TEST_DB_POSTGRES_NAME', "$name (PostgreSQL)");
}

__PACKAGE__->meta->make_immutable;

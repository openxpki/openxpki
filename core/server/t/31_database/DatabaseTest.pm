package DatabaseTest;
use Moose;
use utf8;

use Test::More;
use Test::Exception;
use OpenXPKI::MooseParams;
use Log::Log4perl;
use Moose::Util::TypeConstraints;

################################################################################
# Constructor attributes
#

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
# if not set: do not create table / insert data
has 'data' => (
    is => 'rw',
    isa => 'ArrayRef',
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

# Returns true if the given DB type shall be tested
sub shall_test {
    my ($self, $dbtype) = @_;
    return ($self->test_all_dbs or $self->_test_db(sub {/^\Q$dbtype\E$/}));
}
# if not set: use SQLite in-memory DB
has 'sqlite_db' => (
    is => 'rw',
    isa => 'Str',
);

################################################################################
# Other attributes
#

has 'dbi' => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Database',
);
has 'test_no' => (
    is => 'rw',
    isa => 'Num',
    traits => ['Counter'],
    default => 0,
    handles => {
        count_test => 'inc',
    },
);
has '_log' => (
    is => 'rw',
    isa => 'Object',
#    lazy => 1,
#    default => sub { Log::Log4perl->easy_init($OFF); return Log::Log4perl->get_logger(); }
);

sub set_dbi {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParams
        params => { isa => 'HashRef' },
    );

    lives_ok {
        $self->dbi(
            OpenXPKI::Server::Database->new(
                log => $self->_log, db_params => $args{params},
            )
        );
    } $args{params}->{type}.": create Database instance";

    lives_ok {
        $self->_create_table;
    } $args{params}->{type}.": insert test data" if $self->data;
}

sub BUILD {
    my $self = shift;
    use_ok "OpenXPKI::Server::Database"; $self->count_test;

    Log::Log4perl->init(\"
        log4perl.rootLogger = DEBUG, Everything
        log4perl.appender.Everything          = Log::Log4perl::Appender::String
        log4perl.appender.Everything.layout   = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Everything.layout.ConversionPattern = %d %c.%p %m%n
    ");
    $self->_log( Log::Log4perl->get_logger() );
}

sub _db_test {
    my ($self, $name, $plan, $tests, $dbtype, $dbi_driver, $dbi_params) = positional_args(\@_,
        { isa => 'Str'},
        { isa => 'Str'},
        { isa => 'HashRef'},
        { isa => 'CodeRef' },
    );

    subtest $name => sub {
        $self->shall_test($dbtype) or plan skip_all => "'$dbtype' test disabled";
        eval { require $dbi_driver } or plan skip_all => "$dbi_driver is not installed";
        plan tests => $plan + 1 + ($self->data ? 1 : 0);
        $self->set_dbi(params => $dbi_params);
        $tests->($self);
        $self->_drop_table;
        # esp. prevent prevent deadlocks due to SQLite file locking if second instance of DatabaseTest is used later on:
        $self->dbi->disconnect;
    };
    $self->count_test;
}

sub run {
    my ($self, $name, $plan, $tests) = positional_args(\@_,
        { isa => 'Str'},
        { isa => 'Int'},
        { isa => 'CodeRef' },
    );

    my $test_count = $plan + 1 + ($self->data ? 1 : 0);

    # creates and returns the subtest definition (i.e. coderef)
    my $SUBTEST = sub {
        my ($dbtype, $dbi_driver, $env_var, $dbi_params) = @_;

        my $MAKEPLAN = sub {
            return (skip_all => "$env_var not set") if ($env_var and not $ENV{$env_var});
            return (skip_all => "'$dbtype' test disabled") unless $self->shall_test($dbtype);
            return (skip_all => "$dbi_driver is not installed") unless eval "require $dbi_driver";
            return (tests => $test_count);
        };

        $self->count_test;
        # the actual test sub
        return sub {
            plan $MAKEPLAN->();
            $self->set_dbi(params => $dbi_params);
            $tests->($self);
            $self->_drop_table;
            # esp. prevent prevent deadlocks due to SQLite file locking if second instance of DatabaseTest is used later on:
            $self->dbi->disconnect;
        };
    };

    # SQLite - runs always
    my $sqlite_db = $self->sqlite_db || ":memory:";
    subtest "$name (SQLite '$sqlite_db')" => $SUBTEST->('sqlite', 'DBD::SQLite', '', {
        type => "SQLite",
        name => $sqlite_db,
    });

    # Oracle - runs if OXI_TEST_DB_ORACLE_NAME is set
    subtest "$name (Oracle)" => $SUBTEST->('oracle', 'DBD::Oracle', 'OXI_TEST_DB_ORACLE_NAME', {
        type => "Oracle",
        name => $ENV{OXI_TEST_DB_ORACLE_NAME},
        user => $ENV{OXI_TEST_DB_ORACLE_USER},
        passwd => $ENV{OXI_TEST_DB_ORACLE_PASSWORD},
    });

    # MySQL - runs if OXI_TEST_DB_MYSQL_NAME is set
    my %mysql_params = (
        # if not specified, the driver tries socket connection
        $ENV{OXI_TEST_DB_MYSQL_DBHOST} ? ( host => $ENV{OXI_TEST_DB_MYSQL_DBHOST} ) : (),
        $ENV{OXI_TEST_DB_MYSQL_DBPORT} ? ( port => $ENV{OXI_TEST_DB_MYSQL_DBPORT} ) : (),
        name => $ENV{OXI_TEST_DB_MYSQL_NAME},
        user => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
    );
    subtest "$name (MySQL)" => $SUBTEST->('mysql', 'DBD::mysql', 'OXI_TEST_DB_MYSQL_NAME', {
        type => "MySQL",
        %mysql_params,
    });

    # MariaDB - runs if OXI_TEST_DB_MYSQL_NAME is set
    subtest "$name (MariaDB)" => $SUBTEST->('mariadb', 'DBD::mysql', 'OXI_TEST_DB_MYSQL_NAME', {
        type => "MariaDB",
        %mysql_params,
    });
}

sub get_data {
    my $self = shift;
    my $sth = $self->dbi->select(from => "test", columns => $self->_col_info->{names});
    return $sth->fetchall_arrayref;
}

# Returns all log messages since the last call of this method
sub get_log {
    my $appender = Log::Log4perl->appender_by_name("Everything")
        or BAIL_OUT("Could not access Log4perl appender");
    my $messages = $appender->string;
    $appender->string("");
    return $messages;
}

sub clear_data {
    my $self = shift;
    BAIL_OUT("Cannot re-init data because attribute 'data' was not set") unless $self->data;
    lives_ok {
        $self->_drop_table;
        $self->_create_table;
    } "clear test data";
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

__PACKAGE__->meta->make_immutable;

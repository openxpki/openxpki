package DatabaseTest;
use Moose;
use utf8;

use Test::More;
use Test::Exception;
use File::Spec::Functions qw( catfile catdir splitpath rel2abs );
use MooseX::Params::Validate;

has 'columns' => (
    is => 'rw',
    isa => 'ArrayRef',
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
);
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
);

sub set_dbi {
    my ($self, %args) = validated_hash(\@_,   # MooseX::args::Validate
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
    } $args{params}->{type}.": insert test data";
}

sub BUILD {
    my $self = shift;
    use_ok "OpenXPKI::Server::Database"; $self->count_test;
    use_ok "OpenXPKI::Server::Log";      $self->count_test;
    $self->_log( OpenXPKI::Server::Log->new(
        CONFIG => catfile((splitpath(rel2abs(__FILE__)))[0,1], "log4perl.conf")
    ) );
}

sub run {
    my $self = shift;
    my ($name, $plan, $tests) = pos_validated_list(\@_,
        { isa => 'Str'},
        { isa => 'Int'},
        { isa => 'CodeRef' },
    );

    # SQLite
    subtest "$name (SQLite)" => sub {
        plan tests => $plan + 2; # 2 from set_dbi()
        $self->set_dbi(
            params => {
                type => "SQLite",
                name => ":memory:"
            }
        );
        $tests->($self);
    };
    $self->count_test;

    # Oracle
    subtest "$name (Oracle)" => sub {
        plan skip_all => "No Oracle database found / OXI_TEST_DB_ORACLE_NAME not set" unless $ENV{OXI_TEST_DB_ORACLE_NAME};
        plan tests => $plan + 2; # 2 from set_dbi()
        $self->set_dbi(
            params => {
                type => "Oracle",
                name => $ENV{OXI_TEST_DB_ORACLE_NAME},
                user => $ENV{OXI_TEST_DB_ORACLE_USER},
                passwd => $ENV{OXI_TEST_DB_ORACLE_PASSWORD},
            }
        );
        $tests->($self);
    };
    $self->count_test;

    # MySQL
    subtest "$name (MySQL)" => sub {
        plan skip_all => "No MySQL database found / OXI_TEST_DB_MYSQL_NAME not set" unless $ENV{OXI_TEST_DB_MYSQL_NAME};
        plan tests => $plan + 2; # 2 from set_dbi()
        $self->set_dbi(
            params => {
                type => "MySQL",
                host => "127.0.0.1", # if not specified, the driver tries socket connection
                name => $ENV{OXI_TEST_DB_MYSQL_NAME},
                user => $ENV{OXI_TEST_DB_MYSQL_USER},
                passwd => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
            }
        );
        $tests->($self);
    };
    $self->count_test;
}

sub get_data {
    my $self = shift;
    my $sth = $self->dbi->select(from => "test", columns => $self->_col_info->{names});
    return $sth->fetchall_arrayref;
}

sub clear_data {
    my $self = shift;
    lives_ok {
        $self->_drop_table;
        $self->_create_table;
    } "clear test data";
}

sub _create_table {
    my $self = shift;
    eval { $self->dbi->run("DROP TABLE test") };
    $self->dbi->run("CREATE TABLE test (".join(", ", @{ $self->_col_info->{fulldef} }).")");
    # Create a hash with the column names and the data
    my $col_names = $self->_col_info->{names};
    for my $row (@{ $self->data }) {
        my %values = map { $col_names->[$_] => $row->[$_] } 0..$#{ $col_names };
        $self->dbi->insert(into => "test", values => \%values);
    }
}

sub _drop_table {
    my $self = shift;
    $self->dbi->run("DROP TABLE test");
    $self->dbi->commit;
}

__PACKAGE__->meta->make_immutable;

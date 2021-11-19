package DatabaseTestConnection;
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
    return $self->dbi->select_arrays(from => "test", columns => $self->_col_info->{names});
}

sub clear_data {
    my $self = shift;
    die("Cannot re-init data because attribute 'data' was not set") unless $self->has_data;
    note "Clearing test data";
    $self->_drop_table;
    $self->_create_table;
}

# Returns all log messages since the last call of this method
sub get_log {
    my $appender = Log::Log4perl->appender_by_name("Everything")
        or die("Could not access Log4perl appender");
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

__PACKAGE__->meta->make_immutable;

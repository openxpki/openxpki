package OpenXPKI::Server::Database::Driver::MariaDB2;
use Moose;

with qw(
    OpenXPKI::Server::Database::Role::SequenceSupport
    OpenXPKI::Server::Database::Role::MergeSupport
    OpenXPKI::Server::Database::Role::CountEmulation
    OpenXPKI::Server::Database::Role::Driver
);

=head1 Name

OpenXPKI::Server::Database::Driver::MariaDB2

=cut

# Core modules
use version 0.77;

# CPAN modules
use DBI qw(:sql_types);
use DBI::Const::GetInfoType; # provides %GetInfoType hash
use DBD::MariaDB;
use Capture::Tiny qw( capture_stderr );

# Project Modules
use OpenXPKI::Exception;

################################################################################
# Monkey patch DBI::disconnect_all to suppress warnings that occur due to a bug
# in DBD::MariaDB < v1.20.
#
# DBI has an END block which calls DBI->disconnect_all() which in turn calls the
# driver's disconnect_all() method.
# Due to a driver bug in DBD::MariaDB up to v1.11 the following warnings occur:
#   DBD::MariaDB disconnect_all: 3 database handlers were not released (possible bug in driver) at /usr/local/lib/x86_64-linux-gnu/perl/5.28.1/DBI.pm line 759, <DATA> line 1.
#   DBD::MariaDB disconnect_all: Client library was not properly deinitialized (possible bug in driver) at /usr/local/lib/x86_64-linux-gnu/perl/5.28.1/DBI.pm line 759, <DATA> line 1.
if (version->parse($DBD::MariaDB::VERSION) < version->parse('1.20')) {
    my $_disconnect_all_orig = \&DBI::disconnect_all;
    no warnings qw(redefine);
    *DBI::disconnect_all = sub {
        my $class = shift;
        # silence warnings that occur due to a bug in DBD::MariaDB < v1.20
        my $stderr = capture_stderr {
            $_disconnect_all_orig->($class);
        };
    };
    use warnings qw(redefine);
}

################################################################################
# required by OpenXPKI::Server::Database::Role::Driver
#

# DBI compliant driver name
sub dbi_driver { 'MariaDB' }

# DSN string including all parameters.
sub dbi_dsn {
    my $self = shift;
    # map DBI parameter names to our object attributes
    my %args = (
        database => $self->name,
        host => $self->host,
        port => $self->port,
    );
    return sprintf("dbi:%s:%s",
        $self->dbi_driver,
        join(";", map { "$_=$args{$_}" } grep { defined $args{$_} } keys %args), # only add defined attributes
    );
}

# Additional parameters for DBI's connect()
sub dbi_connect_params {
    # mysql_enable_utf8 => 1,  # not necessary with MariaDB
    mariadb_auto_reconnect => 0, # taken from DBIx::Connector::Driver::mysql::_connect()
    mariadb_bind_type_guessing => 0, # FIXME See https://github.com/openxpki/openxpki/issues/44
}


# Custom checks after driver instantiation
sub perform_checks {
    my ($self, $dbh) = @_;

    # check version
    my $ver = $dbh->get_info($GetInfoType{SQL_DBMS_VER}); # e.g. 5.5.5-10.1.44-MariaDB-1~bionic
    my ($mysql, $major, $minor, $patch) = $ver =~ m/^([\d\.]+-)?(\d+)\.(\d+)\.(\d+)(?:-\w*)?/;
    die "MariaDB server too old: $major.$minor.$patch - OpenXPKI 'MariaDB' driver requires version 10.3, please use 'MySQL' instead."
        unless ($major >= 10 and $minor >= 3);
}

# Commands to execute after connecting
sub on_connect {
    my ($self, $dbh) = @_;

    # set transaction isolation level
    $dbh->do("SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED");

    my $sth = $dbh->prepare("SET SESSION innodb_lock_wait_timeout = ?");
    $sth->bind_param(1, $self->lock_timeout, SQL_INTEGER);
    $sth->execute;
}

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::More source code
}

sub sequence_create_query {
    my ($self, $dbi, $seq) = @_;

    return OpenXPKI::Server::Database::Query->new(
        string => "CREATE SEQUENCE $seq START = 0 INCREMENT = 1 MINVALUE = 0 NOMAXVALUE",
    );
}

# Returns a query that removes an SQL sequence
sub sequence_drop_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP SEQUENCE IF EXISTS $seq",
    );
}

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    return OpenXPKI::Server::Database::Query->new(
        string => "DROP TABLE IF EXISTS $table",
    );
}

sub do_sql_replacements { shift; shift } # return input argument

################################################################################
# required by OpenXPKI::Server::Database::Role::SequenceSupport
#

sub nextval_query {
    my ($self, $seq) = @_;
    return "SELECT NEXTVAL($seq)";
}

################################################################################
# required by OpenXPKI::Server::Database::Role::MergeSupport
#

sub merge_query {
    my ($self, $dbi, $into, $set, $set_once, $where) = @_;
    my %all_val  = ( %$set, %$set_once, %$where );

    return OpenXPKI::Server::Database::Query->new(
        string => sprintf(
            "INSERT INTO %s (%s) VALUES (%s) ON DUPLICATE KEY UPDATE %s",
            $into,
            join(", ", keys %all_val),
            join(", ", map { "?" } (1..scalar keys %all_val)),
            join(", ", map { "$_=?" } keys %$set),
        ),
        params => [
            values %all_val,
            values %$set,
        ]
    );
}

__PACKAGE__->meta->make_immutable;

=head1 Description

Driver for MariaDB servers based on DBD::MariaDB client library.

Requires MariaDB >= 10.3.

Does B<not> work on debian buster due to a bug in DBD::MariaDB v1.11
client library, use the MariaDB class with the old mysql lib instead.

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

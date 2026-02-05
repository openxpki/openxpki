package OpenXPKI::Server::Database::Driver::MariaDB2;
use OpenXPKI -class;

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
use version;

# CPAN modules
use DBI qw(:sql_types);
use DBI::Const::GetInfoType; # provides %GetInfoType hash

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
        join(";", map { "$_=$args{$_}" } grep { defined $args{$_} } sort keys %args), # only add defined attributes
    );
}

# Additional parameters for DBI's connect()
sub dbi_attrs ($self) {
    my %attrs = (
        mariadb_auto_reconnect => 0, # taken from DBIx::Connector::Driver::mysql::_connect()
        mariadb_bind_type_guessing => 0, # FIXME See https://github.com/openxpki/openxpki/issues/44
    );

    # TLS
    if ($self->tls_enabled) {
        die "MariaDB2 requires 'tls.verify_hostname: 0' because system cert store is used, i.e. no 'tls.ca_file' or 'tls.ca_dir' was given\n"
            if ($self->tls_verify_hostname and not ($self->tls_ca_file or $self->tls_ca_dir));

        $attrs{mariadb_ssl} = 1;
        $attrs{mariadb_ssl_ca_file} = $self->tls_ca_file    if $self->tls_ca_file;
        # ssl_ca_path is only supported for if MariaDB client libs use OpenSSL (true for RHEL)
        $attrs{mariadb_ssl_ca_path} = $self->tls_ca_dir     if $self->tls_ca_dir;
        $attrs{mariadb_ssl_verify_server_cert} = 1          if $self->tls_verify_hostname;
    }

    return %attrs;
}

# Custom checks after driver instantiation
sub perform_checks {
    my ($self, $dbh) = @_;

    # check version
    my $ver = $dbh->get_info($GetInfoType{SQL_DBMS_VER}); # e.g. 5.5.5-10.1.44-MariaDB-1~bionic
    my ($mysql, $major, $minor, $patch) = $ver =~ m/^([\d\.]+-)?(\d+)\.(\d+)\.(\d+)(?:-\w*)?/;
    # only MariaDB >= 10.3 has SEQUENCE support
    die "MariaDB server too old: $major.$minor.$patch - OpenXPKI 'MariaDB2' driver requires version 10.03, please use 'MySQL' instead."
        unless (version->parse(sprintf('%d.%03d',$major,$minor)) >= version->parse('10.003'));
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

Driver for MariaDB servers based on L<DBD::MariaDB> client library.

Requires MariaDB >= 10.3.

Does B<not> work on Debian Buster due to a bug in L<DBD::MariaDB> v1.11
client library - please use the C<MariaDB> driver with the old mysql lib instead.

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Server::Database/new> instead.

=cut

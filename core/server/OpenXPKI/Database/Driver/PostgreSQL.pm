package OpenXPKI::Database::Driver::PostgreSQL;
use OpenXPKI -class;

with qw(
    OpenXPKI::Database::Role::SequenceSupport
    OpenXPKI::Database::Role::MergeEmulation
    OpenXPKI::Database::Role::CountEmulation
    OpenXPKI::Database::Role::Driver
);

=head1 Name

OpenXPKI::Database::Driver::PostgreSQL - Driver for PostgreSQL databases

=cut

################################################################################
# required by OpenXPKI::Database::Role::Driver
#

# DBI compliant driver name
sub dbi_driver { 'Pg' }

# DSN string including all parameters.
sub dbi_dsn ($self) {
    my %args = (
        database => $self->name,
        host => $self->host,
        port => $self->port,
    );

    # TLS
    if ($self->tls_enabled) {
        $args{sslmode} = $self->tls_verify_hostname ? 'verify-full' : 'verify-ca';
        # either use specified CA cert file
        if ($self->tls_ca_file) {
            $args{sslrootcert} = $self->tls_ca_file;
        # or (via OpenSSL)
        } else {
            # If sslmode=verify-ca then libpq would fail with:
            # > weak sslmode "verify-ca" may not be used with sslrootcert=system (use "verify-full")
            # We fail earlier here to provide an OpenXPKI-specific error message.
            die "PostgreSQL requires 'tls.verify_hostname' except if you specify 'tls.ca_file'\n"
                if not $self->tls_verify_hostname;
            # a) use system cert dir
            $args{sslrootcert} = 'system';
            # b) use specified cert dir
            $ENV{SSL_CERT_DIR} = $self->tls_ca_dir if $self->tls_ca_dir; # OpenSSL reads SSL_CERT_DIR
        }
    } elsif (not $self->has_tls_enabled) {
        # backwards compatibility: before v3.34 the default was 'sslmode=allow'
        $args{sslmode} = 'allow';
    }

    return sprintf("dbi:%s:%s",
        $self->dbi_driver,
        join(";", map { "$_=$args{$_}" } grep { defined $args{$_} } sort keys %args), # only add defined attributes
    );
}

# Additional parameters for DBI's connect()
sub dbi_attrs {
    pg_enable_utf8 => 1,
}

# Custom checks after driver instantiation
sub perform_checks { }

# Commands to execute after connecting
sub on_connect {
    my ($self, $dbh) = @_;
    $dbh->do("SET SESSION CHARACTERISTICS AS TRANSACTION ISOLATION LEVEL READ COMMITTED");
    $dbh->do("SET client_min_messages TO warning");
    $dbh->do("SET lock_timeout TO ?", undef, $self->lock_timeout * 1000);
    # PostgreSQL settings get lost if the current transaction is rolled back, so we commit here.
    # DBI logger and session handler have autocommit on and DBI cause a warning on superflous
    # commits so we need to make this conditional
    $dbh->commit unless($dbh->{AutoCommit});
}

# Parameters for SQL::Abstract::More
sub sqlam_params {
    limit_offset => 'LimitOffset',    # see SQL::Abstract::More source code
}

sub sequence_create_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Database::Query->new(
        string => "CREATE SEQUENCE $seq START WITH 0 INCREMENT BY 1 MINVALUE 0 NO MAXVALUE",
    );
}

# Returns a query that removes an SQL sequence
sub sequence_drop_query {
    my ($self, $dbi, $seq) = @_;
    return OpenXPKI::Database::Query->new(
        string => "DROP SEQUENCE IF EXISTS $seq",
    );
}

sub table_drop_query {
    my ($self, $dbi, $table) = @_;
    return OpenXPKI::Database::Query->new(
        string => "DROP TABLE IF EXISTS $table",
    );
}

sub do_sql_replacements {
    my ($self, $sql) = @_;

    $sql =~ s/from_unixtime \s* \( \s* ( [^\)]+ ) \)/TO_TIMESTAMP($1)/gmsxi;

    return $sql;
}

################################################################################
# required by OpenXPKI::Database::Role::SequenceSupport
#

sub nextval_query {
    my ($self, $seq) = @_;
    return "SELECT NEXTVAL('$seq')";
}

__PACKAGE__->meta->make_immutable;

=head1 Description

This class is not meant to be instantiated directly.
Use L<OpenXPKI::Database/new> instead.

=cut

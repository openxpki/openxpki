package OpenXPKI::Test;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test - Set up an OpenXPKI test environment.

=cut

# Core modules
use Data::Dumper;
use File::Temp qw( tempdir );

# CPAN modules
use Moose::Exporter;
use Log::Log4perl;
use Moose::Util::TypeConstraints;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test

# Project modules
use OpenXPKI::Config;
use OpenXPKI::Server::Database;
use OpenXPKI::Server::Log::NOOP;
use OpenXPKI::Server::Context;
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session::Mock;
use OpenXPKI::Test::ConfigWriter;
use OpenXPKI::Test::CertHelper::Database;

Moose::Exporter->setup_import_methods(
    as_is     => [ 'OpenXPKI::Server::Context::CTX' ],
);

=head1 DESCRIPTION

=head2 Database

C<OpenXPKI::Test> tries to read the following sources to determine the database
connection parameters and stops as soon as it can find some:

=over

=item 1. Constructor attribute C<db_conf>.

=item 2. I</etc/openxpki/config.d/system/database.yaml>. This can be prevented
by setting C<force_test_db =E<gt> 1>.

=item 3. Environment variables C<$ENV{OXI_TEST_DB_MYSQL_XXX}>.

=back

If no database parameters are found anywhere it dies with an error.

=cut

=head1 METHODS

=head2 new

Constructor.

B<Parameters>

=over

=item * I<db_conf> (optional) - Database configuration (I<HashRef>).

Per default the configuration is read from an existing configuration file
(below I</etc/openxpki>) or environment variables.

=cut
has db_conf => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    builder => '_build_db_conf',
    predicate => 'has_db_conf',
    trigger => sub {
        my ($self, $new, $old) = @_;
        my @keys = qw( type name host port user passwd );
        die "Required keys missing for 'db_conf': ".join(", ", grep { not defined $new->{$_} } @keys)
            unless eq_deeply([keys %$new], bag(@keys));
    },
);

=item * I<dbi> (optional) - instance of L<OpenXPKI::Server::Database>.

Per default it is initialized with a new instance using C<$self-E<gt>db_conf>.

=cut
has dbi => (
    is => 'rw',
    isa => 'OpenXPKI::Server::Database',
    lazy => 1,
    builder => '_build_dbi',
);


=item * I<force_test_db> - Set to 1 to prevent the try to read database config
from existing configuration file and only read it from environment variables
C<$ENV{OXI_TEST_DB_MYSQL_XXX}>.

=cut
has force_test_db => (
    is => 'rw',
    isa => 'Bool',
    lazy => 1,
    default => 0,
);

=back

=cut

=head2 setup_env

Set up the test environment.

=over

=item * reads the database configuration,

=item * creates a temporary directory with YAML configuration files,

=item * initializes the basic context objects:

=over 1

=item * C<CTX('config')>

=item * C<CTX('log')>

=item * C<CTX('dbi_backend')>

=item * C<CTX('dbi_workflow')>

=item * C<CTX('dbi')>

=item * C<CTX('api')>

=item * C<CTX('session')>

Note that C<CTX('session')-E<gt>get_pki_realm> will return the first realm
specified in L<OpenXPKI::Test::ConfigWriter/realms>.

=back

=back

Returns the temporary directory which serves as filesystem base for the test
environment.

=cut
sub setup_env {
    my ($self) = @_;

    my $session = OpenXPKI::Server::Session::Mock->new;
    OpenXPKI::Server::Context::setcontext({'session' => $session});
    $session->set_pki_realm('dummy'); # initial dummy realm

    # Init Log4perl
    $self->_init_screen_log;

    # Read database configuration

    # Create base directory for test configuration
    my $tmp = tempdir( CLEANUP => 1 );
    $ENV{OPENXPKI_CONF_PATH} = "$tmp/etc/openxpki/config.d"; # so OpenXPKI::Config will access our config from now on

    # Write configuration YAML files
    my $cfg = OpenXPKI::Test::ConfigWriter->new(
        basedir     => $tmp,
        db_conf     => $self->db_conf,
    );
    $cfg->create;

    $session->set_pki_realm($cfg->realms->[0]);

    # Init basic CTX objects
    OpenXPKI::Server::Init::init({
        TASKS  => [ qw( config_versioned dbi_log log dbi_backend dbi_workflow dbi api ) ],
        SILENT => 1,
        CLI => 0
    });
    # set context session item again because OpenXPKI::Server::Init::init deleted it
    OpenXPKI::Server::Context::setcontext({'session' => $session});

    OpenXPKI::Server::Context::CTX('dbi_backend')->connect;
    OpenXPKI::Server::Context::CTX('dbi_workflow')->connect;

    return $tmp;
}

=head2 certhelper_database

Returns an instance of L<OpenXPKI::Test::CertHelper::Database> with the database
configuration set to C<$self-E<gt>db_conf>.

=cut
sub certhelper_database {
    my ($self) = @_;

    return OpenXPKI::Test::CertHelper::Database->new(dbi => $self->dbi);
}

sub _build_dbi {
    my ($self) = @_;

    return OpenXPKI::Server::Database->new(
        log => OpenXPKI::Server::Log::NOOP->new,
        db_params => $self->db_conf,
    );
}

sub _build_db_conf {
    my ($self) = @_;

    my $conf;
    $conf = $self->_db_config_from_production unless $self->force_test_db;
    $conf ||= $self->_db_config_from_env;
    die "Could not read database config from /etc/openxpki or env variables" unless $conf;
    return $conf;
}

sub _db_config_from_production {
    my ($self) = @_;

    return unless (-d "/etc/openxpki/config.d" and -r "/etc/openxpki/config.d");

    # make sure OpenXPKI::Config reads from default /etc/openxpki/config.d
    my $old_env = $ENV{OPENXPKI_CONF_PATH}; delete $ENV{OPENXPKI_CONF_PATH};
    my $config = OpenXPKI::Config->new;
    $ENV{OPENXPKI_CONF_PATH} = $old_env if $old_env;

    my $db_conf = $config->get_hash('system.database.main');
    my $conf = {
        type    => $db_conf->{type},
        name    => $db_conf->{name},
        host    => $db_conf->{host},
        port    => $db_conf->{port},
        user    => $db_conf->{user},
        passwd  => $db_conf->{passwd},
    };
    # Set environment variables
    my $db_env = $config->get_hash("system.database.main.environment");
    $ENV{$_} = $db_env->{$_} for (keys %{$db_env});

    return $conf;
}

sub _db_config_from_env {
    my ($self) = @_;

    return unless $ENV{OXI_TEST_DB_MYSQL_NAME};

    return {
        type    => "MySQL",
        name    => $ENV{OXI_TEST_DB_MYSQL_NAME},
        host    => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
        port    => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
        user    => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd  => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},

    };
}

sub _init_screen_log {
    my ($self) = @_;

    my $threshold_screen = $ENV{TEST_VERBOSE} ? 'INFO' : 'ERROR';
    Log::Log4perl->init(
        \qq(
            # Catch-all root logger
            log4perl.rootLogger = ERROR, Screen

            log4perl.category.openxpki.auth = INFO, Screen
            log4perl.category.openxpki.audit = INFO, Screen
            log4perl.category.openxpki.monitor = INFO, Screen
            log4perl.category.openxpki.system = INFO, Screen
            log4perl.category.openxpki.workflow = INFO, Screen
            log4perl.category.openxpki.application = INFO, Screen
            log4perl.category.connector = INFO, Screen

            log4perl.appender.Screen          = Log::Log4perl::Appender::Screen
            log4perl.appender.Screen.layout   = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.Screen.layout.ConversionPattern = %d %c.%p %m%n
            log4perl.appender.Screen.Threshold = $threshold_screen
        )
    );
}

__PACKAGE__->meta->make_immutable;

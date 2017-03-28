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
use OpenXPKI::Server::Context;
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session::Mock;
use OpenXPKI::Test::ConfigWriter;

Moose::Exporter->setup_import_methods(
    as_is     => [ 'OpenXPKI::Server::Context::CTX' ],
);

=head1 DESCRIPTION

=cut

=head1 METHODS

=head2 new

Constructor.

Per default, C<OpenXPKI::Test> tries to read the database configuration from
I</etc/openxpki/config.d/system/database.yaml>. This can be prevented by
setting C<force_test_db =E<gt> 1>.

B<Parameters>

=over

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

=item * I<db_conf> - Database configuration (I<HashRef>). Setting this will
prevent the try to read it from an existing configuration file or env vars.

=cut
has db_conf => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
    predicate => 'has_db_conf',
    trigger => sub {
        my ($self, $new, $old) = @_;
        my @keys = qw( type name host port user passwd );
        die "Required keys missing for 'db_conf': ".join(", ", grep { not defined $new->{$_} } @keys)
            unless eq_deeply([keys %$new], bag(@keys));
    },
);

=back

=cut

=head2 create

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

=item * C<CTX('session')> (C<CTX('session')-E<gt>get_pki_realm> will return the
first realm specified in L<OpenXPKI::Test::ConfigWriter/realms>)

=back

=back

Returns the temporary path which serves as filesystem base for the temporary
test environment.

=cut
sub setup_env {
    my ($self) = @_;

    # Init Log4perl
    $self->_init_screen_log;

    # Read database configuration
    $self->_db_config_from_production unless ($self->has_db_conf or $self->force_test_db);
    $self->_db_config_from_env        unless $self->has_db_conf;
    die "Could not read database config from /etc/openxpki or env variables" unless $self->has_db_conf;

    # Create base directory for test configuration
    my $tmp = tempdir( CLEANUP => 1 );
    $ENV{OPENXPKI_CONF_PATH} = "$tmp/etc/openxpki/config.d"; # so OpenXPKI::Config will access our config from now on

    # Write configuration YAML files
    my $cfg = OpenXPKI::Test::ConfigWriter->new(
        basedir     => $tmp,
        db_conf     => $self->db_conf,
    );
    $cfg->create;

    # Init basic CTX objects
    OpenXPKI::Server::Init::init({TASKS  => [ qw( config_versioned dbi_log log dbi_backend dbi_workflow dbi api ) ], SILENT => 1, CLI => 0});
    OpenXPKI::Server::Context::CTX('dbi_backend')->connect;
    OpenXPKI::Server::Context::CTX('dbi_workflow')->connect;

    my $session = OpenXPKI::Server::Session::Mock->new;
    OpenXPKI::Server::Context::setcontext({'session' => $session});
    $session->set_pki_realm($cfg->realms->[0]);

    return $tmp;
}

sub _db_config_from_production {
    my ($self) = @_;

    return unless (-d "/etc/openxpki/config.d" and -r "/etc/openxpki/config.d");

    # make sure OpenXPKI::Config reads from default /etc/openxpki/config.d
    my $old_env = $ENV{OPENXPKI_CONF_PATH}; delete $ENV{OPENXPKI_CONF_PATH};

    my $config = OpenXPKI::Config->new;
    my $db_conf = $config->get_hash('system.database.main');

    $self->db_conf({
        type    => $db_conf->{type},
        name    => $db_conf->{name},
        host    => $db_conf->{host},
        port    => $db_conf->{port},
        user    => $db_conf->{user},
        passwd  => $db_conf->{passwd},
    });

    # Set environment variables
    my $db_env = $config->get_hash("system.database.main.environment");
    $ENV{$_} = $db_env->{$_} for (keys %{$db_env});

    $ENV{OPENXPKI_CONF_PATH} = $old_env if $old_env;
}

sub _db_config_from_env {
    my ($self) = @_;

    $self->db_conf({
        type    => "MySQL",
        name    => $ENV{OXI_TEST_DB_MYSQL_NAME},
        host    => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
        port    => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
        user    => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd  => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},

    });
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

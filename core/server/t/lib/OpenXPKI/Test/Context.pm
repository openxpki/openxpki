package OpenXPKI::Test::Context;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::Context - Initialize C<CTX> for use in test code.

=cut

use Moose::Util::TypeConstraints;

use Test::More;
use Test::Exception;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test

=head1 DESCRIPTION

This class initializes some parts of the global context C<CTX> for tests of
encapsulated OpenXPKI functionality that does not need more complex global
functions like workflows.

This allows for tests to run without starting a complete OpenXPKI server and
without setting up a configuration file.

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

has is_log_initialized          => ( is => 'rw', isa => 'Bool', default => 0 );
has is_legacydb_initialized     => ( is => 'rw', isa => 'Bool', default => 0 );
has is_legacydb_log_initialized => ( is => 'rw', isa => 'Bool', default => 0 );
has is_db_initialized           => ( is => 'rw', isa => 'Bool', default => 0 );
has is_mock_session_initialized => ( is => 'rw', isa => 'Bool', default => 0 );
has is_api_initialized          => ( is => 'rw', isa => 'Bool', default => 0 );

#
# Init logging
#
sub init_screen_log {
    my ($self) = @_;
    return if $self->is_log_initialized; # Do not switch back so screen only logging once full logging is enabled

    diag "Initialize CTX('log') for screen only logging";
    use OpenXPKI::Server::Log;
    my $threshold_screen = $ENV{TEST_VERBOSE} ? 'INFO' : 'ERROR';
    OpenXPKI::Server::Context::setcontext({
        log => OpenXPKI::Server::Log->new(CONFIG => \qq(
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
        ))
    });
}

sub init_log {
    my ($self) = @_;
    # Always rerun in case we switch from screen logging to full logging

    diag "Initialize CTX('log')";

    $self->_init_legacydb_log;

    use OpenXPKI::Server::Log;
    use OpenXPKI::Server::Log::Appender::DBI;

    my $threshold_screen = $ENV{TEST_VERBOSE} ? 'INFO' : 'ERROR';
    OpenXPKI::Server::Context::setcontext({
        log => OpenXPKI::Server::Log->new(CONFIG => \qq(
            # Catch-all root logger
            log4perl.rootLogger = ERROR, Screen

            log4perl.category.openxpki.auth = INFO, Screen, DBI
            log4perl.category.openxpki.audit = INFO, Screen, DBI
            log4perl.category.openxpki.monitor = INFO, Screen, DBI
            log4perl.category.openxpki.system = INFO, Screen, DBI
            log4perl.category.openxpki.workflow = INFO, Screen, DBI
            log4perl.category.openxpki.application = INFO, Screen, DBI
            log4perl.category.connector = INFO, Screen

            log4perl.appender.DBI              = OpenXPKI::Server::Log::Appender::DBI
            log4perl.appender.DBI.layout       = Log::Log4perl::Layout::NoopLayout
            log4perl.appender.DBI.warp_message = 0

            log4perl.appender.Screen          = Log::Log4perl::Appender::Screen
            log4perl.appender.Screen.layout   = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.Screen.layout.ConversionPattern = %d %c.%p %m%n
            log4perl.appender.Screen.Threshold = $threshold_screen
        ))
    });

    $self->is_log_initialized(1);
}

#
# Init legacy DB layer
#
sub _init_legacydb_log {
    my ($self) = @_;
    return if $self->is_legacydb_log_initialized;

    diag "Initialize CTX('dbi_log') / legacy db";

    die "Database config HashRef 'db_conf' is not set" unless $self->has_db_conf;

    use OpenXPKI::Server::DBI;
    use OpenXPKI::Server::Log::NOOP;
    use OpenXPKI::Server::Context qw( CTX );

    OpenXPKI::Server::Context::setcontext({
        dbi_log => OpenXPKI::Server::DBI->new(
            SERVER_ID => 0,
            SERVER_SHIFT => 8,
            LOG         => OpenXPKI::Server::Log::NOOP->new,
            TYPE        => $self->db_conf->{type},
            NAME        => $self->db_conf->{name},
            HOST        => $self->db_conf->{host},
            PORT        => $self->db_conf->{port},
            USER        => $self->db_conf->{user},
            PASSWD      => $self->db_conf->{passwd},
        )
    });
    CTX('dbi_log')->connect;

    $self->is_legacydb_log_initialized(1);
}

sub _init_legacydb {
    my ($self) = @_;
    return if $self->is_legacydb_initialized;

    diag "Initialize CTX('dbi_xxx') / legacy db";

    die "Database config HashRef 'db_conf' is not set" unless $self->has_db_conf;

    $self->init_log;

    use OpenXPKI::Server::DBI;
    use OpenXPKI::Server::Context qw( CTX );

    OpenXPKI::Server::Context::setcontext({
        dbi_backend => OpenXPKI::Server::DBI->new(
            SERVER_ID => 0,
            SERVER_SHIFT => 8,
            LOG         => CTX('log'),
            TYPE        => $self->db_conf->{type},
            NAME        => $self->db_conf->{name},
            HOST        => $self->db_conf->{host},
            PORT        => $self->db_conf->{port},
            USER        => $self->db_conf->{user},
            PASSWD      => $self->db_conf->{passwd},
        )
    });
    CTX('dbi_backend')->connect;

    OpenXPKI::Server::Context::setcontext({
        dbi_workflow => OpenXPKI::Server::DBI->new(
            SERVER_ID => 0,
            SERVER_SHIFT => 8,
            LOG         => CTX('log'),
            TYPE        => $self->db_conf->{type},
            NAME        => $self->db_conf->{name},
            HOST        => $self->db_conf->{host},
            PORT        => $self->db_conf->{port},
            USER        => $self->db_conf->{user},
            PASSWD      => $self->db_conf->{passwd},
        )
    });
    CTX('dbi_workflow')->connect;

    $self->is_legacydb_initialized(1);
}

#
# Init DB layer
#
sub init_db {
    my ($self) = @_;
    return if $self->is_db_initialized;

    diag "Initialize CTX('dbi')";

    die "Database config HashRef 'db_conf' is not set" unless $self->has_db_conf;

    use OpenXPKI::Server::Init; # for unknown reason this is needed
    $self->init_log;
    $self->_init_legacydb;

    use OpenXPKI::Server::Database;
    use OpenXPKI::Server::Context qw( CTX );

    OpenXPKI::Server::Context::setcontext({
        dbi => OpenXPKI::Server::Database->new(
            log => CTX('log'),
            db_params => {
                type        => $self->db_conf->{type},
                name        => $self->db_conf->{name},
                host        => $self->db_conf->{host},
                port        => $self->db_conf->{port},
                user        => $self->db_conf->{user},
                passwd      => $self->db_conf->{passwd},
            },
        ),
    });

    $self->is_db_initialized(1);
}

#
# Init session mockup
#
sub init_mock_session {
    my ($self) = @_;
    return if $self->is_mock_session_initialized;

    diag "Initialize CTX('session')";

    use OpenXPKI::Server::Session::Mock;
    use OpenXPKI::Server::Database;

    OpenXPKI::Server::Context::setcontext({
        session => OpenXPKI::Server::Session::Mock->new
    });

    $self->is_mock_session_initialized(1);
}

#
# Init API
#
sub init_api {
    my ($self) = @_;
    return if $self->is_api_initialized;

    diag "Initialize CTX('api')";

    $self->init_log;

    use OpenXPKI::Server::API;

    OpenXPKI::Server::Context::setcontext({
        api => OpenXPKI::Server::API->new,
    });

    $self->is_api_initialized(1);
}

sub init_all {
    my ($self) = @_;

    subtest "Initialize CTX" => sub {
        $self->init_db;
        $self->init_mock_session;
        $self->init_api;
    }
}

__PACKAGE__->meta->make_immutable;


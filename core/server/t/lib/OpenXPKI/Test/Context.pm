package OpenXPKI::Test::Context;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test::Context - Initialize C<CTX> for use in test code.

=cut

use Test::More;
use Test::Exception;

=head1 DESCRIPTION

This class initializes some parts of the global context C<CTX> for tests of
encapsulated OpenXPKI functionality that does not need more complex global
functions like workflows.

This allows for tests to run without starting a complete OpenXPKI server and
without setting up a configuration file.

=cut

has is_log_initialized          => ( is => 'rw', isa => 'Bool', default => 0 );
has is_legacydb_initialized     => ( is => 'rw', isa => 'Bool', default => 0 );
has is_legacydb_log_initialized => ( is => 'rw', isa => 'Bool', default => 0 );
has is_db_initialized           => ( is => 'rw', isa => 'Bool', default => 0 );
has is_mock_session_initialized => ( is => 'rw', isa => 'Bool', default => 0 );
has is_api_initialized          => ( is => 'rw', isa => 'Bool', default => 0 );

#
# Init logging
#
sub init_log {
    my ($self) = @_;
    return if $self->is_log_initialized;

    subtest "Initialize CTX('log')" => sub {
        $self->_init_legacydb_log;

        use_ok "OpenXPKI::Server::Log";
        use_ok "OpenXPKI::Server::Log::Appender::DBI";
        lives_ok {
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
        } "Instantiate class and setup context 'log'";
    };
    $self->is_log_initialized(1);
}

#
# Init legacy DB layer
#
sub _init_legacydb_log {
    my ($self) = @_;
    return if $self->is_legacydb_log_initialized;

    subtest "Initialize CTX('dbi_log') / legacy db" => sub {
        use_ok "OpenXPKI::Server::DBI";
        use_ok "OpenXPKI::Server::Log::NOOP";
        use_ok "OpenXPKI::Server::Context", qw( CTX );

        lives_ok {
            OpenXPKI::Server::Context::setcontext({
                dbi_log => OpenXPKI::Server::DBI->new(
                    SERVER_ID => 0,
                    SERVER_SHIFT => 8,
                    LOG         => OpenXPKI::Server::Log::NOOP->new,
                    TYPE        => "MySQL",
                    NAME        => $ENV{OXI_TEST_DB_MYSQL_NAME},
                    HOST        => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
                    PORT        => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
                    USER        => $ENV{OXI_TEST_DB_MYSQL_USER},
                    PASSWD      => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
                )
            });
            CTX('dbi_log')->connect;
        } "Instantiate class and setup context 'dbi_log'";
    };
    $self->is_legacydb_log_initialized(1);
}

sub _init_legacydb {
    my ($self) = @_;
    return if $self->is_legacydb_initialized;

    subtest "Initialize CTX('dbi_xxx') / legacy db" => sub {
        $self->init_log;

        use_ok "OpenXPKI::Server::DBI";
        use_ok "OpenXPKI::Server::Context", qw( CTX );

        lives_ok {
            OpenXPKI::Server::Context::setcontext({
                dbi_backend => OpenXPKI::Server::DBI->new(
                    SERVER_ID => 0,
                    SERVER_SHIFT => 8,
                    LOG         => CTX('log'),
                    TYPE        => "MySQL",
                    NAME        => $ENV{OXI_TEST_DB_MYSQL_NAME},
                    HOST        => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
                    PORT        => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
                    USER        => $ENV{OXI_TEST_DB_MYSQL_USER},
                    PASSWD      => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
                )
            });
            CTX('dbi_backend')->connect;
        } "Instantiate class and setup context 'dbi_backend'";

        lives_ok {
            OpenXPKI::Server::Context::setcontext({
                dbi_workflow => OpenXPKI::Server::DBI->new(
                    SERVER_ID => 0,
                    SERVER_SHIFT => 8,
                    LOG         => CTX('log'),
                    TYPE        => "MySQL",
                    NAME        => $ENV{OXI_TEST_DB_MYSQL_NAME},
                    HOST        => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
                    PORT        => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
                    USER        => $ENV{OXI_TEST_DB_MYSQL_USER},
                    PASSWD      => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
                )
            });
            CTX('dbi_workflow')->connect;
        } "Instantiate class and setup context 'dbi_workflow'";
    };
    $self->is_legacydb_initialized(1);
}

#
# Init DB layer
#
sub init_db {
    my ($self) = @_;
    return if $self->is_db_initialized;

    subtest "Initialize CTX('dbi')" => sub {
        use_ok "OpenXPKI::Server::Init"; # for unknown reason this is needed
        $self->init_log;
        $self->_init_legacydb;

        use_ok "OpenXPKI::Server::Database";
        use_ok "OpenXPKI::Server::Context", qw( CTX );

        lives_ok {
            OpenXPKI::Server::Context::setcontext({
                dbi => OpenXPKI::Server::Database->new(
                    log => CTX('log'),
                    db_params => {
                        type    => "MySQL",
                        name    => $ENV{OXI_TEST_DB_MYSQL_NAME},
                        host    => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
                        port    => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
                        user    => $ENV{OXI_TEST_DB_MYSQL_USER},
                        passwd  => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},
                    },
                ),
            });
        } "Instantiate class and setup context";
    };
    $self->is_db_initialized(1);
}

#
# Init session mockup
#
sub init_mock_session {
    my ($self) = @_;
    return if $self->is_mock_session_initialized;

    subtest "Initialize CTX('session')" => sub {
        use_ok "OpenXPKI::Server::Session::Mock";
        use_ok "OpenXPKI::Server::Database";
        lives_ok {
            OpenXPKI::Server::Context::setcontext({
                session => OpenXPKI::Server::Session::Mock->new
            });
        } "Instantiate class and setup context";
    };
    $self->is_mock_session_initialized(1);
}

#
# Init API
#
sub init_api {
    my ($self) = @_;
    return if $self->is_api_initialized;

    subtest "Initialize CTX('api')" => sub {
        $self->init_log;

        use_ok "OpenXPKI::Server::API";
        lives_ok {
            OpenXPKI::Server::Context::setcontext({
                api => OpenXPKI::Server::API->new,
            });
        } "Instantiate class and setup context";
    };
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

1;

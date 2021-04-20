package OpenXPKI::Test;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test - Set up an OpenXPKI test environment.

=head1 SYNOPSIS

Basic test environment:

    my $oxitest = OpenXPKI::Test->new;

Start an OpenXPKI test server:

    my $oxitest = OpenXPKI::Test->new(with => [ qw( SampleConfig Server ) ]);
    my $client = $oxitest->new_client_tester;
    # $client is a "OpenXPKI::Test::QA::Role::Server::ClientHelper"
    $client->connect;
    $client->init_session;
    $client->login("caop");

=head1 DESCRIPTION

This class is the central new (as of 2017) test vehicle for OpenXPKI that sets
up a separate test environment where all configuration data resides in a
temporary directory C<$oxitest-E<gt>testenv_root."/etc/openxpki/config.d">.

Methods of this class do not execute any tests themselves, i.e. do not increment
the test count of C<Test::More>.

Tests in OpenXPKI are split into two groups:

=over

=item * I<unit tests> in C<core/server/t/> that test single classes and limited
functionality and don't need a running server or a complete configuration.

=item * I<QA tests> in C<qatest/> that need a running server or a more complete
test configuration.

=back

This class can be used for both types of tests.

To set up a basic test environment, just do

    my $oxitest = OpenXPKI::Test->new;

This provides the following OpenXPKI context objects:

    CTX('config')
    CTX('log')
    CTX('dbi')
    CTX('api2')
    CTX('authentication')
    CTX('session')        # in-memory
    CTX('notification')   # mockup

The session PKI realm is set to I<TestRealm> and the user role to I<User>.

At this point, various more complex functions (e.g. crypto operations) will not
be available, but the test environment can be extended via:

=over

=item * B<additional configuration entries> (constructor parameter
C<add_config>)

=item * B<additional OpenXPKI context objects> that should be initialized
(constructor parameter C<also_init>)

=item * B<Moose roles> to apply to C<OpenXPKI::Test> that provide more complex
extensions (constructor parameter C<with>)

=back

For more details, see the L<constructor documentation|/new>.

=head2 More complex tests via Moose roles

The existing roles add more complex configuration and initialization to test
more functions. They can easily be applied by using the L<constructor|/new>
parameter C<with>.

Available Moose roles can be found at these two locations:

1. C<core/server/t/lib/OpenXPKI/Test/Role> (roles for unit tests and QA
tests):

=over

=item * L<CryptoLayer|OpenXPKI::Test::Role::CryptoLayer>

=item * L<TestRealms|OpenXPKI::Test::Role::TestRealms>

=back

2. C<qatest/lib/OpenXPKI/Test/QA/Role/> (roles exclusively for QA tests):

=over

=item * L<SampleConfig|OpenXPKI::Test::QA::Role::SampleConfig>

=item * L<Server|OpenXPKI::Test::QA::Role::Server>

=item * L<WorkflowCreateCert|OpenXPKI::Test::QA::Role::WorkflowCreateCert>

=item * L<Workflows|OpenXPKI::Test::QA::Role::Workflows>

=back

PLEASE NOTE: tests currently still use the production database but it is planned
to use a separate SQLite DB for all tests in the future.

B<Examples:>

Additionally provide C<CTX('crypto_layer')>:

    my $oxitest = OpenXPKI::Test->new(with => "CryptoLayer");

Use default configuration shipped with OpenXPKI and start a test server (only
available for QA tests):

    my $oxitest = OpenXPKI::Test->new(with => [ qw( SampleConfig Server ) ]);

=head2 Debugging

To display debug statements just use L<OpenXPKI::Debug> in your test files
B<before> you use C<OpenXPKI::Test>:

    # e.g. in t/mytest.t
    use strict;
    use warnings;

    use Test::More;

    use OpenXPKI::Debug;
    BEGIN { $OpenXPKI::Debug::LEVEL{'OpenXPKI::Server::Database.*'} = 0b1111111 }

    use OpenXPKI::Test;

=cut

# Core modules
use Data::Dumper;
use File::Temp qw( tempdir );
use Module::Load qw( autoload );

# CPAN modules
use Moose::Exporter;
use Moose::Util;
use Moose::Meta::Class;
use Moose::Util::TypeConstraints;
use Test::More;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test
use Digest::SHA;
use MIME::Base64;
use YAML::Tiny;

# Project modules
use OpenXPKI::Config;
use OpenXPKI::Log4perl;
use Log::Log4perl::Appender;
use Log::Log4perl::Filter::MDC;
use Log::Log4perl::Layout::NoopLayout;
use OpenXPKI::MooseParams;
use OpenXPKI::Server::Database;
use OpenXPKI::Server::Context;
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Log;
use OpenXPKI::Server::Session;
use OpenXPKI::Test::ConfigWriter;
use OpenXPKI::Test::CertHelper::Database;

Moose::Exporter->setup_import_methods(
    as_is     => [ \&OpenXPKI::Server::Context::CTX ],
);

subtype 'TestArrayRefOrStr', as 'ArrayRef[Any]';
coerce 'TestArrayRefOrStr', from 'Str', via { [ $_ ] };

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

=head1 METHODS

=head2 new

Constructor.

B<Parameters> (these are Moose attributes and can be accessed as such)

=over

=item * I<with> (optional) - Scalar or ArrayRef containing the full package or
last part of Moose roles to apply to C<OpenXPKI::Test>. Currently the
following names might be specified:

For unit tests (I<core/server/t/>) or QA tests (I<qatest/>):

=over

=item * L<CryptoLayer|OpenXPKI::Test::Role::CryptoLayer> - also init
C<CTX('crypto_layer')>

=item * L<TestRealms|OpenXPKI::Test::Role::TestRealms> - add test realms
I<alpha>, I<beta> and I<gamma> to configuration

=back

Only for QA tests (I<qatest/>):

=over

=item * L<SampleConfig|OpenXPKI::Test::QA::Role::SampleConfig> - use
the complete default configuration shipped with OpenXPKI (slightly modified)

=item * L<Server|OpenXPKI::Test::QA::Role::Server> - run OpenXPKI as a
background server daemon and talk to it via client (socket)

=item * L<Workflows|OpenXPKI::Test::QA::Role::Workflows> - also init
C<CTX('workflow_factory')> and provide some helper methods

=item * L<WorkflowCreateCert|OpenXPKI::Test::QA::Role::WorkflowCreateCert>
- easily create test certificates

=back

For each given string C<NAME> the following packages are tried for Moose role
application: C<NAME> (unmodified string), C<OpenXPKI::Test::Role::NAME>,
C<OpenXPKI::Test::QA::Role::NAME>

=item * I<add_config> (optional) - I<HashRef> with additional configuration
entries that complement or replace the default config.

Keys are the dot separated configuration paths, values are HashRefs or YAML
strings with the actual configuration data that will be merged (and finally
converted into YAML and stored on disk in a temporary directory).

Example:

    OpenXPKI::Test->new(
        add_config => {
            "realm.alpha.auth.handler.Signature1" => {
                realm => [ "alpha" ],
                cacert => [ "MyCertId" ],
            },
            # or:
            "realm.alpha.auth.handler.Signature2" => "
                realm:
                 - alpha
                cacert:
                 - MyCertId
            ",
        }
    );

This would write the following content into I<etc/openxpki/config.d/realm/alpha.yaml>
(below C<$oxitest-E<gt>testenv_root>):

    ...
    Signature
      realm:
        - alpha
      cacert:
        - MyCertId
    ...

=cut
has user_config => (
    is => 'rw',
    isa => 'HashRef',
    init_arg => 'add_config',
    lazy => 1,
    default => sub {
        my $self = shift;
        $self->has_user_config_sub ? $self->user_config_sub->($self) : {};
    },
);

=item * I<add_config_sub> (optional) - intead of C<add_config> specifies a
I<CodeRef> which must return a I<HashRef> with additional configuration
entries.

The specified sub receives the C<OpenXPKI::Test> object as first parameter, so
it is able to access other configuration entries.

Please note that you CANNOT specify both C<add_config> and C<add_config_sub>.

Example:

    OpenXPKI::Test->new(
        add_config_sub => sub {
            my $test = shift;
            return {
                "some.special.entry" => $test->testenv_root . "/mydir";
            };
        }
    );

=cut
has user_config_sub => (
    is => 'rw',
    isa => 'CodeRef',
    init_arg => 'add_config_sub',
    predicate => 'has_user_config_sub',
);

=item * I<also_init> (optional) - ArrayRef (or Str) of additional init tasks
that the OpenXPKI server shall perform.

You have to make sure (e.g. by adding additional config entries) that the
prerequisites for each task are met.

=cut
has also_init => (
    is => 'rw',
    isa => 'TestArrayRefOrStr',
    lazy => 1,
    coerce => 1,
    default => sub { [] },
);

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
        my @keys = qw( type name user passwd );
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

=item * I<testenv_root> (optional) - Temporary directory that serves as root
path for the test environment (configuration files etc.). Default: newly created
directory that will be deleted on object destruction

=cut
has testenv_root => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { scalar(tempdir( CLEANUP => 1 )) },
);

=item * I<log_level> (optional) - L<Log::Log4Perl> log level for screen output.
This is only relevant if C<$ENV{TEST_VERBOSE}> is set, i.e. user calls C<prove -v ...>.
Otherwise logging will be disabled anyway. Default: WARN

=cut
has log_level => (
    is => 'rw',
    isa => 'Str',
    default => "WARN",
);

=item * I<enable_workflow_log> (optional) - if set to 1 workflow related log
entries will be written into the database. This allows e.g. for querying the
workflow log / history.

Per default when using this test class there is only screen logging.

=cut
has enable_workflow_log => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

=item * I<enable_file_log> - if set to 1 all log messages above log level DEBUG
are written to a temporary file for manual inspection.

Also see L</log_path> and L</diag_log>.

=cut
has enable_file_log => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);


=back

=head2 certhelper_database

Returns an instance of L<OpenXPKI::Test::CertHelper::Database> with the database
configuration set to C<$self-E<gt>db_conf>.

=cut
has certhelper_database => (
    is => 'rw',
    isa => 'OpenXPKI::Test::CertHelper::Database',
    lazy => 1,
    default => sub { OpenXPKI::Test::CertHelper::Database->new },
);

=head2 config_writer

Returns an instance of L<OpenXPKI::Test::ConfigWriter>.

=cut
has config_writer => (
    is => 'rw',
    isa => 'OpenXPKI::Test::ConfigWriter',
    lazy => 1,
    default => sub {
        my $self = shift;
        OpenXPKI::Test::ConfigWriter->new(
            basedir => $self->testenv_root,
        )
    },
    handles => {
        add_conf => "add_config",
        get_conf => "get_config_node",
    },
);
=head2 add_conf

Just a shortcut to L<OpenXPKI::Test::ConfigWriter/add_config>.

=head2 get_conf

Just a shortcut to L<OpenXPKI::Test::ConfigWriter/get_config_node>.

=cut


=head2 default_realm

Returns the configured default realm.

=cut
has default_realm => (
    is => 'rw',
    isa => 'Str',
    init_arg => undef,
    predicate => 'has_default_realm',
);

=head2 session

Returns the session context object C<CTX('session')> once L</init_server> was
called.

=cut
has session => (
    is => 'rw',
    isa => 'Object',
    init_arg => undef,
    predicate => 'has_session',
);

=head2 log_path

Returns the path to the log file if the constructor has been called with
C<enable_file_log =E<gt> 1>.

=cut
has log_path => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { my $self = shift; $self->testenv_root."/openxpki.log" },
    init_arg => undef,
);

has path_log4perl_conf  => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/etc/openxpki/log.conf" } );
has conf_log4perl       => ( is => 'rw', isa => 'Str',    lazy => 1, builder => "_build_log4perl" );
has conf_session        => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_conf_session" );
has conf_database       => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_conf_database" );
# password for all openxpki users
has password            => ( is => 'rw', isa => 'Str', lazy => 1, default => "openxpki" );
has password_hash       => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { my $self = shift; $self->_get_password_hash($self->password) } );
has auth_stack          => ( is => 'ro', isa => 'Str', lazy => 1, default => "Testing" );

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my @args = @_;

    if (@args % 2 == 0) {
        my %arg_hash = @args;

        if (my $roles = delete $arg_hash{with}) {
            die "Parameter 'with' must be a Scalar or an ArrayRef of role names" if (ref $roles and ref $roles ne 'ARRAY');
            $roles = [ $roles ] if not ref $roles;
            for my $shortname (@$roles) {
                my $role;
                # Try loading the role with given name and below both test namespaces
                for my $namespace ("", "OpenXPKI::Test::Role::", "OpenXPKI::Test::QA::Role::") {
                    my $p = "${namespace}${shortname}";
                    # if package is not found, autoload() dies and eval() returns
                    eval { autoload $p };
                    if (not $@) { $role = $p; last }
                }
                die "Could not find test class role '$shortname'" unless $role;
                Moose::Util::ensure_all_roles($class, $role);
            }
        }
        @args = %arg_hash;
    }
    return $class->$orig(@args);
};

sub BUILD {
    my $self = shift;

    $ENV{OXI_TESTENV_ROOT} = $self->testenv_root;

    $self->init_logging;
    $self->init_base_config;
    $self->init_user_config;
    $self->write_config;
    $self->init_server;
    #
    # Please note: if you change the following lines, add every call
    # after $self->init_server also to
    # OpenXPKI::Test::QA::Role::Server, modifier "around 'init_server'", the
    # child code after $self->$orig()
    #
    $self->init_session_and_context;
}

sub _build_log4perl {
    my ($self, $is_early_init) = @_;

    # special behaviour in CI environments: log to file
    # (detects Travis CI/CircleCI/Gitlab CI/Appveyor/CodeShip + Jenkins/TeamCity)
    if ($ENV{CI} or $ENV{BUILD_NUMBER}) {
        my $logfile = $self->config_writer->path_log_file;
        return qq(
            log4perl.rootLogger = INFO, CatchAll
            log4perl.category.Workflow = OFF
            log4perl.appender.CatchAll = Log::Log4perl::Appender::File
            log4perl.appender.CatchAll.filename = $logfile
            log4perl.appender.CatchAll.layout = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.CatchAll.layout.ConversionPattern = %d %m [pid=%P|%i]%n
            log4perl.appender.CatchAll.syswrite  = 1
            log4perl.appender.CatchAll.utf8 = 1
        );
    }
    # default: only log to screen
    return $self->_log4perl_screen;
}

sub _log4perl_screen {
    my ($self) = @_;

    my $threshold_screen = $ENV{TEST_VERBOSE} ? uc($self->log_level) : 'OFF';
    my $log_path = $self->log_path;
    return qq(
        log4perl.rootLogger                     = INFO, Screen, File
        log4perl.category.openxpki.auth         = TRACE
        log4perl.category.openxpki.audit        = TRACE
        log4perl.category.openxpki.system       = TRACE
        log4perl.category.openxpki.workflow     = TRACE
        log4perl.category.openxpki.application  = TRACE
        log4perl.category.openxpki.deprecated   = WARN
        log4perl.category.connector             = WARN
        log4perl.category.Workflow              = OFF

        log4perl.appender.Screen                = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.layout         = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = # %d %m [pid=%P|%i]%n
        log4perl.appender.Screen.Threshold      = $threshold_screen

        # "File" is disabled by default
        log4perl.appender.File                  = Log::Log4perl::Appender::File
        log4perl.appender.File.filename         = $log_path
        log4perl.appender.File.syswrite         = 1
        log4perl.appender.File.utf8             = 1
        log4perl.appender.File.layout           = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.File.layout.ConversionPattern = # %d %m [pid=%P|%i]%n
        log4perl.appender.File.Threshold        = OFF
    );
}

sub _build_conf_session {
    my ($self) = @_;
    return {
        type => "Database",
        lifetime => "1200",
        table => "backend_session",
    };
}


sub _build_conf_database {
    my ($self) = @_;
    return {
        main => {
            debug   => 0,
            type    => $self->db_conf->{type},
            $self->db_conf->{host} ? ( host => $self->db_conf->{host} ) : (),
            $self->db_conf->{port} ? ( port => $self->db_conf->{port} ) : (),
            name    => $self->db_conf->{name},
            user    => $self->db_conf->{user},
            passwd  => $self->db_conf->{passwd},
        },
    };
}

=head2 init_logging

B<Only called internally:> initialize logging.

=cut
sub init_logging {
    my ($self) = @_;

    note "[OpenXPKI::Test->init_logging]";

    OpenXPKI::Log4perl->init_or_fallback( \($self->_log4perl_screen) );

    # additional workflow log (database)
    if ($self->enable_workflow_log) {
        my $appender = Log::Log4perl::Appender->new(
            "OpenXPKI::Server::Log::Appender::Database",
            table => "application_log",
            microseconds => 1,
        );
        $appender->layout(Log::Log4perl::Layout::NoopLayout->new()),
        $appender->filter(Log::Log4perl::Filter::MDC->new(
            KeyToMatch    => "wfid",
            RegexToMatch  => '\d+',
        ));
        Log::Log4perl->get_logger("openxpki.application")->add_appender($appender);
    }

    # additional file log
    if ($self->enable_file_log) {
        # We cannot use Log::Log4perl->appender_by_name("File")->threshold(uc($self->log_level));
        # as this accesses the actual appender class, but we need the wrapper class Log::Log4perl::Appender
        # (https://www.perlmonks.org/?node_id=1199218)
        $Log::Log4perl::Logger::APPENDER_BY_NAME{'File'}->threshold('DEBUG');
        note "  >";
        note "  > All log messages (log level DEBUG) will be written to:";
        note "  > ".$self->log_path;
        note "  >";
    }
}

=head2 diag_log

Outputs all log entries in the log file (only if enabled via constructor
parameter C<enable_file_log>).

Output is done via C<diag()>.

=cut
sub diag_log {
    my ($self) = @_;
    return unless $self->enable_file_log;
    open my $fh, '<', $self->log_path or return;

    local $/; # slurp mode
    my $logs = <$fh>;
    close $fh;
    diag $logs;
}

=head2 init_base_config

B<Only called internally:> pass base config entries to L<OpenXPKI::Test::ConfigWriter>.

This is the standard hook for test class roles to add configuration entries.
So in a role you can e.g. inject configuration entries as follows:

    after 'init_base_config' => sub {
        my $self = shift;

        # do not overwrite existing node (e.g. inserted by other roles)
        if (not $self->get_conf("a.b.c", 1)) {
            $self->add_conf(
                "a.b.c" => {
                    key => "value",
                },
            );
        }
    };

=cut
sub init_base_config {
    my ($self) = @_;

    note "[OpenXPKI::Test->init_base_config]";

    $self->add_conf(
        "system.database" => $self->conf_database,
        "system.server.session" => $self->conf_session,
        "system.server.log4perl" => $self->path_log4perl_conf,
    );
}

=head2 init_user_config

B<Only called internally:> pass additional config entries that were supplied via
constructor parameter C<add_config> to L<OpenXPKI::Test::ConfigWriter>.

=cut
sub init_user_config {
    my ($self) = @_;

    note "[OpenXPKI::Test->init_user_config]";

    # Add basic test realm.
    # Without any realm we cannot set a user via CTX('authentication')
    $self->add_conf(
        "system.realms.test" => {
            label => "TestRealm",
            baseurl => "http://127.0.0.1/test/",
        },
        "realm.test.auth" => $self->auth_config,
        "realm.test.workflow.def" => {},
    );

    # Add user supplied config (via constructor argument "add_config")
    for (sort keys %{ $self->user_config }) { # sorting should help adding config items deeper in the tree after those at the top
        my $val = $self->user_config->{$_};
        # support config given as YAML string
        if (ref $val eq '') {
            $val = YAML::Tiny->read_string($val)->[0];
        }
        $self->add_conf($_ => $val);
    }

    if (not $self->has_default_realm) {
        note "  Setting default realm to 'test' as no other realm was set";
        $self->default_realm('test');
    }
    else {
        note "  Default realm: ".$self->default_realm;
    }
}

=head2 write_config

B<Only called internally:> write test configuration to disk (temporary directory).

=cut
sub write_config {
    my ($self) = @_;

    note "[OpenXPKI::Test->write_config]";

    # write configuration YAML files
    $self->config_writer->create;

    # write Log4perl config: it's OK to do this late because we already initialize Log4perl in init_logging()
    $self->config_writer->write_str($self->path_log4perl_conf, $self->conf_log4perl);

    # store private key files in temp env/dir
    for my $cert ($self->certhelper_database->all_certs) {
        $self->config_writer->write_private_key($cert->db->{pki_realm}, $cert->name, $cert->private_key);
    }

    # point server to the test config dir (evaluated by OpenXPKI::Config)
    $ENV{OPENXPKI_CONF_PATH} = $self->testenv_root."/etc/openxpki/config.d";

    # point clients to the test config dir (evaluated by OpenXPKI::Client::Config)
    # -> CURRENTLY UNUSED as this affects only (est|rpc|scep|soap).fcgi which are not tested
    $ENV{OPENXPKI_CLIENT_CONF_DIR} = $self->testenv_root."/etc/openxpki";
}

=head2 init_server

B<Only called internally:> initializes the basic server context objects:

    C<CTX('config')>
    C<CTX('log')>
    C<CTX('dbi')>
    C<CTX('api2')>
    C<CTX('authentication')>

=cut
sub init_server {
    my ($self) = @_;

    note "[OpenXPKI::Test->init_server]";

    OpenXPKI::Server::Context::reset();
    OpenXPKI::Server::Init::reset();

    # init log object (and force it to NOT reinitialize Log4perl)
    OpenXPKI::Server::Context::setcontext({ log => OpenXPKI::Server::Log->new(CONFIG => undef) })
        unless OpenXPKI::Server::Context::hascontext("log"); # may already be set if multiple instances of OpenXPKI::Test are created

    # init basic CTX objects
    my @tasks = qw( config_versioned dbi_log api2 authentication );

    # init notification object if needed
    my $cfg_notification = "realm.".$self->default_realm.".notification";
    if ($self->get_conf($cfg_notification, 1)) {
        note "  Config node $cfg_notification found, initializing real CTX('notification') object";
        push @tasks, "notification";
    }

    # add tasks requested via constructor parameter "also_init" (or injected by roles)
    my %task_hash = map { $_ => 1 } @tasks;
    for (grep { not $task_hash{$_} } @{ $self->also_init }) {
        push @tasks, $_;
        $task_hash{$_} = 1; # prevent duplicate tasks in "also_init"
    }

    OpenXPKI::Server::Init::init({ TASKS  => \@tasks, SILENT => 1, CLI => 0 });

    # use the same DB connection as the test object to be able to do COMMITS
    # etc. in tests
    OpenXPKI::Server::Context::setcontext({ dbi => $self->dbi })
        unless OpenXPKI::Server::Context::hascontext("dbi"); # may already be set if multiple instances of OpenXPKI::Test are created

    # Set fake notification object if there is no real one already
    # (either via setup above or requested by user)
    if (not OpenXPKI::Server::Context::hascontext("notification")) {
        note "  Initializing mockup CTX('notification') object";
        OpenXPKI::Server::Context::setcontext({
            notification =>
                Moose::Meta::Class->create('OpenXPKI::Test::AnonymousClass::Notification::Mockup' => (
                    methods => {
                        notify => sub { },
                    },
                ))->new_object
        });
    }

}

=head2 init_session_and_context

B<Only called internally:> create in-memory session C<CTX('session')> and (if there
is no other object already) a mock notification objection C<CTX('notification')>.

This is the standard hook for roles to modify session data, e.g.:

    after 'init_session_and_context' => sub {
        my $self = shift;
        $self->session->data->pki_realm("democa") if $self->has_session;
    };

=cut
sub init_session_and_context {
    my ($self) = @_;

    note "[OpenXPKI::Test->init_session_and_context]";

    $self->session(OpenXPKI::Server::Session->new(load_config => 1)->create);

    # Set session separately (OpenXPKI::Server::Init::init "killed" any old one)
    OpenXPKI::Server::Context::setcontext({
        session => $self->session,
        force => 1,
    });

    # set default user (after session init as CTX('session') is needed by auth handler
    $self->set_user($self->default_realm, "user");
}

=head2 set_user

Directly sets the current PKI realm and user in the session without any login
process.

The user must exist within the authentication config path, i.e. as
I<realm.RRR.auth.handler.HHH.user.USER>.

B<Positional Parameters>

=over

=item * C<$realm> I<Str> - PKI realm

=item * C<$user> I<Str> - username

=back

=cut
sub set_user {
    my ($self, $realm, $user) = @_;

    $self->session->data->pki_realm($realm);

    my ($realuser, $role, $reply) = OpenXPKI::Server::Context::CTX('authentication')->login_step({
        STACK   => $self->auth_stack,
        MESSAGE => {
            PARAMS => { LOGIN => $user, PASSWD => $self->password },
        },
    });

    die "Could not set user to '$user': ".Dumper($reply) unless $realuser && $role;

    $self->session->data->user($realuser);
    $self->session->data->role($role);
    $self->session->is_valid(1);

    Log::Log4perl::MDC->put('user', $realuser);
    Log::Log4perl::MDC->put('role', $role);

    note "  session set to realm '$realm', user '$user', role '$role'";
}

=head2 api2_command

Executes the given API2 command and returns the result.

Convenience method to prevent usage of C<CTX('api2')> in test files.

B<Positional Parameters>

=over

=item * C<$command> I<Str> - command name

=item * C<$params> I<HashRef> - parameters

=back

=cut
sub api2_command {
    my ($self, $command, $params) = @_;
    return OpenXPKI::Server::Context::CTX('api2')->$command($params ? (%$params) : ());
}

=head2 insert_testcerts

Inserts all or the specified list of test certificates from
L<OpenXPKI::Test::CertHelper::Database> into the database.

B<Parameters>

=over

=item * C<only> I<ArrayRef> - only add the given certificates (expects names like I<alpha-root-1>)

=item * C<exclude> I<ArrayRef> - exclude the given certificates

=back

=cut
sub insert_testcerts {
    my ($self, %args) = named_args(\@_,
        exclude => { isa => 'ArrayRef', optional => 1 },
        only => { isa => 'ArrayRef', optional => 1 },
    );

    die "Either specify 'only' or 'exclude', not both." if $args{only} && $args{exclude};

    my $certhelper = $self->certhelper_database;
    my $certnames;
    if ($args{only}) {
        $certnames = $args{only};
    }
    elsif ($args{exclude}) {
        my $exclude = { map { $_ => 1 } @{ $args{exclude} } };
        $certnames = [ grep { not $exclude->{$_} } $certhelper->all_cert_names ];
    }
    else {
        $certnames = [ $certhelper->all_cert_names ];
    }

    $self->dbi->start_txn;

    $self->dbi->merge(
        into => "certificate",
        set => $certhelper->cert($_)->db,
        where => { subject_key_identifier => $certhelper->cert($_)->subject_key_id },
    ) for @{ $certnames };

    for (@{ $certnames }) {
        next unless $certhelper->cert($_)->db_alias->{alias};
        $self->dbi->merge(
            into => "aliases",
            set => {
                %{ $certhelper->cert($_)->db_alias },
                identifier  => $certhelper->cert($_)->db->{identifier},
                notbefore   => $certhelper->cert($_)->db->{notbefore},
                notafter    => $certhelper->cert($_)->db->{notafter},
            },
            where => {
                pki_realm   => $certhelper->cert($_)->db->{pki_realm},
                alias       => $certhelper->cert($_)->db_alias->{alias},
            },
        );
    }
    $self->dbi->commit;
}

=head2 delete_all

Deletes all test certificates from the database.

=cut
sub delete_testcerts {
    my ($self) = @_;
    my $certhelper = $self->certhelper_database;

    $self->dbi->start_txn;
    $self->dbi->delete(from => 'certificate', where => { identifier => $certhelper->all_cert_ids } );
    $self->dbi->delete(from => 'aliases',     where => { identifier => [ map { $_->db->{identifier} } $certhelper->all_certs ] } );
    $self->dbi->delete(from => 'crl',         where => { issuer_identifier => [ map { $_->id } $certhelper->all_certs ] } );
    $self->dbi->commit;
}

sub _build_dbi {
    my ($self) = @_;

    #Log::Log4perl->easy_init($OFF);
    return OpenXPKI::Server::Database->new(
        # "CONFIG => undef" prevents OpenXPKI::Server::Log from re-initializing Log4perl
        log => OpenXPKI::Server::Log->new(CONFIG => undef)->system,
        db_params => $self->db_conf,
    );
}

# TODO Remove "force_test_db", add "sqlite", under qatest/ the default should be _db_config_from_env() and under core/server/t it should be an SQLite DB
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

    # make sure OpenXPKI::Config::Backend reads from the given LOCATION
    my $old_env = $ENV{OPENXPKI_CONF_PATH}; delete $ENV{OPENXPKI_CONF_PATH};
    my $config = OpenXPKI::Config::Backend->new(LOCATION => "/etc/openxpki/config.d");
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
        type    => "MariaDB",
        $ENV{OXI_TEST_DB_MYSQL_DBHOST} ? ( host => $ENV{OXI_TEST_DB_MYSQL_DBHOST} ) : (),
        $ENV{OXI_TEST_DB_MYSQL_DBPORT} ? ( port => $ENV{OXI_TEST_DB_MYSQL_DBPORT} ) : (),
        name    => $ENV{OXI_TEST_DB_MYSQL_NAME},
        user    => $ENV{OXI_TEST_DB_MYSQL_USER},
        passwd  => $ENV{OXI_TEST_DB_MYSQL_PASSWORD},

    };
}


sub _get_password_hash {
    my ($self, $password) = @_;
    my $salt = "";
    $salt .= chr(int(rand(256))) for (1..3);
    $salt = encode_base64($salt);

    my $ctx = Digest::SHA->new;
    $ctx->add($password);
    $ctx->add($salt);
    return "{ssha}".encode_base64($ctx->digest . $salt, '');
}

sub auth_config {
    my ($self) = @_;
    return {
        stack => {
            $self->auth_stack() => {
                description => "OpenXPKI test authentication stack",
                handler => "OxiTest",
                type  => "Password",
            },
        },
        handler => {
            "OxiTest" => {
                label => "OpenXPKI test authentication handler",
                type  => "Password",
                user  => {
                    # password is always "openxpki"
                    caop => {
                        digest => $self->password_hash, # "{ssha}JQ2BAoHQZQgecmNjGF143k4U2st6bE5B",
                        role   => "CA Operator",
                    },
                    raop => {
                        digest => $self->password_hash,
                        role   => "RA Operator",
                    },
                    raop2 => {
                        digest => $self->password_hash,
                        role   => "RA Operator",
                    },
                    user => {
                        digest => $self->password_hash,
                        role   => "User"
                    },
                    user2 => {
                        digest => $self->password_hash,
                        role   => "User"
                    },
                },
            },
        },
        roles => {
            "Anonymous"   => { label => "Anonymous" },
            "CA Operator" => { label => "CA Operator" },
            "RA Operator" => { label => "RA Operator" },
            "System"      => { label => "System" },
            "User"        => { label => "User" },
        },
    };
}

1;

package OpenXPKI::Test;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test - Set up an OpenXPKI test environment.

=head1 SYNOPSIS

Basic test environment:

    my $oxitest = OpenXPKI::Test->new;

Running OpenXPKI test server:

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
the test count of L<Test::More>.

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
    CTX('api')
    CTX('api2')
    CTX('authentication')
    CTX('session') (in-memory)
    CTX('notification') (mockup)

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

=head2 Moose roles

The existing roles add more complex configuration and initialization to test
more functions. They can easily be applied by using the L<constructor|/new>
parameter C<with>.

Available Moose roles can be found at these two locations:

=over

=item * C<core/server/t/lib/OpenXPKI/Test/Role> (roles for unit tests and QA
tests)

=item * C<qatest/lib/OpenXPKI/Test/QA/Role/> (roles exclusively for QA tests)

=back

PLEASE NOTE: tests currently still use the production database but it is planned
to use a separate SQLite DB for all tests in the future.

=head2 More complex tests via Moose roles

For details please see L<constructor|/new> parameter C<with>.

B<Examples:>

Additionally provide C<CTX('crypto_layer')>:

    my $oxitest = OpenXPKI::Test->new(with => "CryptoLayer");

Use default configuration shipped with OpenXPKI and start a test server (only
available for QA tests):

    my $oxitest = OpenXPKI::Test->new(with => [ qw( SampleConfig Server ) ]);

=cut

# Core modules
use Data::Dumper;
use File::Temp qw( tempdir );
use Module::Load qw( autoload );

# CPAN modules
use Moose::Exporter;
use Moose::Util;
use Moose::Meta::Class;
use Log::Log4perl qw(:easy);
use Log::Log4perl::Appender;
use Log::Log4perl::Filter::MDC;
use Moose::Util::TypeConstraints;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test
use Digest::SHA;
use MIME::Base64;

# Project modules
use OpenXPKI::Config;
use OpenXPKI::MooseParams;
use OpenXPKI::Server::Database;
use OpenXPKI::Server::Context;
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Test::ConfigWriter;
use OpenXPKI::Test::CertHelper::Database;

Moose::Exporter->setup_import_methods(
    as_is     => [ \&OpenXPKI::Server::Context::CTX ],
);

subtype 'ArrayRefOrStr', as 'ArrayRef[Any]';
coerce 'ArrayRefOrStr', from 'Str', via { [ $_ ] };

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

For unit tests below I<core/server/t/> or QA tests:

=over

=item * L<CryptoLayer|OpenXPKI::Test::Role::CryptoLayer> - also init
C<CTX('crypto_layer')>

=back

Only for QA tests below I<qatest/>:

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

Keys are the dot separated configuration paths, values are HashRefs with the
actual configuration data that will be converted into YAML and stored on disk.

Example:

    OpenXPKI::Test->new(
        add_config => {
            "realm.alpha.auth.handler.Signature" => {
                realm => [ "alpha" ],
                cacert => [ "MyCertId" ],
            }
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
    isa => 'ArrayRefOrStr',
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
            db_conf => $self->db_conf,
            log_level => $self->log_level,
        )
    },
);

=head2 session

Returns the session context object (C<CTX('session')> once L</init_server> was
called.

=cut
has session => (
    is => 'rw',
    isa => 'Object',
    init_arg => undef,
    predicate => 'has_session',
);

=head2 last_api_result

Returns the result of last call to L</api_command> or L</api2_command>.

=cut
#
has last_api_result => (
    is => 'rw',
    isa => 'Any',
    init_arg => undef,
    predicate => 'has_last_api_result',
);

has path_log4perl_conf  => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { shift->testenv_root."/etc/openxpki/log.conf" } );
has conf_log4perl       => ( is => 'rw', isa => 'Str',    lazy => 1, builder => "_build_log4perl" );
has conf_session        => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_conf_session" );
has conf_database       => ( is => 'rw', isa => 'HashRef', lazy => 1, builder => "_build_conf_database" );
# password for all openxpki users
has password            => ( is => 'rw', isa => 'Str', lazy => 1, default => "openxpki" );
has password_hash       => ( is => 'rw', isa => 'Str', lazy => 1, default => sub { my $self = shift; $self->_get_password_hash($self->password) } );

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
                Moose::Util::apply_all_roles($class, $role);
            }
        }
        @args = %arg_hash;
    }
    return $class->$orig(@args);
};

sub BUILD {
    my $self = shift;
    $self->init_logging;
    $self->init_base_config;
    $self->init_user_config;
    $self->write_config;
    $self->init_server;
    $self->init_session_and_context;
}

sub _build_log4perl {
    my ($self, $is_early_init) = @_;

    # special behaviour CI environments: log to file
    # (detects Travis CI/CircleCI/Gitlab CI/Appveyor/CodeShip + Jenkins/TeamCity)
    if ($ENV{CI} or $ENV{BUILD_NUMBER}) {
        my $logfile = $self->config_writer->path_log_file;
        return qq(
            log4perl.rootLogger = INFO, CatchAll
            log4perl.category.Workflow = OFF
            log4perl.appender.CatchAll = Log::Log4perl::Appender::File
            log4perl.appender.CatchAll.filename = $logfile
            log4perl.appender.CatchAll.layout = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.CatchAll.layout.ConversionPattern = %d %c.%p %m [pid=%P|%i]%n
            log4perl.appender.CatchAll.syswrite  = 1
            log4perl.appender.CatchAll.utf8 = 1
        );
    }
    # default: only log to screen
    return $self->_log4perl_screen;
}

sub _log4perl_screen {
    my ($self) = @_;

    my $threshold_screen = $ENV{TEST_VERBOSE} ? $self->log_level : 'OFF';
    return qq(
        log4perl.rootLogger                     = INFO,  Screen
        log4perl.category.openxpki.auth         = DEBUG, Screen
        log4perl.category.openxpki.audit        = DEBUG, Screen
        log4perl.category.openxpki.system       = DEBUG, Screen
        log4perl.category.openxpki.workflow     = DEBUG, Screen
        log4perl.category.openxpki.application  = DEBUG, Screen
        log4perl.category.openxpki.deprecated   = WARN,  Screen
        log4perl.category.connector             = WARN,  Screen
        log4perl.category.Workflow              = OFF

        log4perl.appender.Screen                = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.layout         = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = # %d %c %p %m [pid=%P|%i]%n
        log4perl.appender.Screen.Threshold      = $threshold_screen
    );
}

sub _build_conf_session {
    my ($self) = @_;
    return {
        type => "Database",
        lifetime => "1200",
    };
}


sub _build_conf_database {
    my ($self) = @_;
    return {
        main => {
            debug   => 0,
            type    => $self->db_conf->{type},
            name    => $self->db_conf->{name},
            host    => $self->db_conf->{host},
            port    => $self->db_conf->{port},
            user    => $self->db_conf->{user},
            passwd  => $self->db_conf->{passwd},
        },
    };
}

# while testing we do not log to database by default
=head2 enable_workflow_log

Enables writing of workflow related log entries into the database. This allows
e.g. for querying the workflow log.

Per default when using this test class there is only screen logging.

=cut
sub enable_workflow_log {
    my ($self) = @_;

    my $appender = Log::Log4perl::Appender->new(
        "OpenXPKI::Server::Log::Appender::Database",
        layout   => Log::Log4perl::Layout::PatternLayout->new("%m (%X{user}"),
        table => "application_log",
        microseconds => 1,
    );
    $appender->filter(Log::Log4perl::Filter::MDC->new(
        KeyToMatch    => "wfid",
        RegexToMatch  => '\d+',
    ));
    Log::Log4perl->get_logger("openxpki.application")->add_appender($appender);
}

=head2 init_logging

Basic test setup: logging.

=cut
sub init_logging {
    my ($self) = @_;
    Log::Log4perl->init( \($self->_log4perl_screen) );
}

=head2 init_base_config

Basic test setup: pass base config entries to L<OpenXPKI::Test::ConfigWriter>.

This is the standard hook for roles to add configuration entries:

    after 'init_base_config' => sub {
        my $self = shift;

        # do not overwrite existing node (e.g. inserted by OpenXPKI::Test::QA::Role::SampleConfig)
        if (not $self->config_writer->get_config_node("a.b.c", 1)) {
            $self->config_writer->add_user_config(
                "a.b.c" => {
                    key   => "value",
                },
            );
        }
    };

=cut
sub init_base_config {
    my ($self) = @_;
    $self->config_writer->add_user_config(
        "system.database" => $self->conf_database,
        "system.server.session" => $self->conf_session,
        "system.server.log4perl" => $self->path_log4perl_conf,
    );
}

=head2 init_user_config

Basic test setup: pass additional config entries (supplied via constructor
parameter C<add_config>) to L<OpenXPKI::Test::ConfigWriter>.

=cut
sub init_user_config {
    my ($self) = @_;
    for (keys %{ $self->user_config }) {
        $self->config_writer->add_user_config($_ => $self->user_config->{$_});
    }
}

=head2 write_config

Write test configuration to disk (temporary directory).

=cut
sub write_config {
    my ($self) = @_;

    # write configuration YAML files
    $self->config_writer->create;

    # write Log4perl config: it's OK to do this late because we already initialize Log4perl in init_logging()
    $self->config_writer->write_str($self->path_log4perl_conf, $self->conf_log4perl);

    # store private key files in temp env/dir
    # TODO This is hackish, OpenXPKI::Test::CertHelper::Database needs to store infos about realms as well (be authoritative source about realms/certs for tests)
    for my $alias (keys %{ $self->certhelper_database->private_keys }) {
        my $realm = (split("-", $alias))[0]; die "Could not extract realm from alias $alias" unless $realm;
        $self->config_writer->write_private_key($realm, $alias, $self->certhelper_database->private_keys->{$alias});
    }

    # set test config dir in ENV so OpenXPKI::Config will access it from now on
    $ENV{OPENXPKI_CONF_PATH} = $self->testenv_root."/etc/openxpki/config.d";
}

=head2 init_server

Initializes the basic server context objects:

    C<CTX('config')>
    C<CTX('log')>
    C<CTX('dbi')>
    C<CTX('api')>
    C<CTX('api2')>
    C<CTX('authentication')>

=cut
sub init_server {
    my ($self) = @_;

    # Init basic CTX objects
    my @tasks = qw( config_versioned log dbi_log dbi api2 api authentication );
    my %task_hash = map { $_ => 1 } @tasks;
    # add tasks requested via constructor parameter "also_init" (or injected by roles)
    for (grep { not $task_hash{$_} } @{ $self->also_init }) {
        push @tasks, $_;
        $task_hash{$_} = 1; # prevent duplicate tasks in "also_init"
    }
    OpenXPKI::Server::Init::init({ TASKS  => \@tasks, SILENT => 1, CLI => 0 });
}

=head2 init_session_and_context

Basic test setup: create in-memory session (C<CTX('session')>) and a mock
notification objection (C<CTX('notification')>).

This is the standard hook for roles to modify session data, e.g.:

    after 'init_session_and_context' => sub {
        my $self = shift;
        $self->session->data->pki_realm("ca-one") if $self->has_session;
    };

=cut
sub init_session_and_context {
    my ($self) = @_;

    $self->session(OpenXPKI::Server::Session->new(load_config => 1)->create);
    # set default PKI realm
    $self->session->data->pki_realm("alpha");

    # Set session separately (OpenXPKI::Server::Init::init "killed" any old one)
    OpenXPKI::Server::Context::setcontext({
        session => $self->session,
        force => 1,
    });

    # Set fake notification object
    OpenXPKI::Server::Context::setcontext({
        notification =>
            Moose::Meta::Class->create('OpenXPKI::Test::AnonymousClass::Notification::Mockup' => (
                methods => {
                    notify => sub { },
                },
            ))->new_object
    });
}

=head2 get_config

Returns a all config data that was defined below the given dot separated config
path. This might be a HashRef (config node) or a Scalar (config leaf).

The data might be taken from parent and/or child config definitions, e.g.:

C<get_config_entry('realm.alpha.workflow')> might return data from

=over

=item * realm/alpha.yaml

=item * realm/alpha/workflow.yaml

=item * realm/alpha/workflow/def/creation.yaml

=item * realm/alpha/workflow/def/deletion.yaml

=back

B<Parameters>

=over

=item * I<$config_key> - dot separated configuration key/path

=item * I<$allow_undef> - set to 1 to return C<undef> instead of dying if the
config key is not found

=back

=cut
sub get_config {
    my ($self, $config_key, $allow_undef) = @_;
    $self->config_writer->get_config_node($config_key, $allow_undef);
}

=head2 api_command

Executes the given API2 command and stores the result in L</last_api_result>
(additionally to returning it).

Convenience method to prevent usage of CTX('api') in test files.

B<Positional Parameters>

=over

=item * C<$command> I<Str> - command name

=item * C<$params> I<HashRef> - parameters

=back

=cut
sub api_command {
    my ($self, $command, $params) = @_;

    my $result = OpenXPKI::Server::Context::CTX('api')->$command($params);
    $self->last_api_result($result);

    return $result;
}

=head2 api2_command

Executes the given API2 command and stores the result in L</last_api_result>
(additionally to returning it).

Convenience method to prevent usage of CTX('api2') in test files.

B<Positional Parameters>

=over

=item * C<$command> I<Str> - command name

=item * C<%params> I<Hash> - parameters as plain list

=back

=cut
sub api2_command {
    my ($self, $command, %params) = @_;

    my $result = OpenXPKI::Server::Context::CTX('api2')->$command(%params);
    $self->last_api_result($result);

    return $result;
}

=head2 insert_testcerts

Inserts all test certificates from L<OpenXPKI::Test::CertHelper::Database> into
the database.

=cut
sub insert_testcerts {
    my ($self) = @_;
    my $certhelper = $self->certhelper_database;

    $self->dbi->start_txn;

    $self->dbi->merge(
        into => "certificate",
        set => $certhelper->cert($_)->db,
        where => { subject_key_identifier => $certhelper->cert($_)->id },
    ) for @{ $certhelper->all_cert_names };

    for (@{ $certhelper->all_cert_names }) {
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
    $self->dbi->delete(from => 'certificate', where => { subject_key_identifier => $certhelper->all_cert_ids } );
    $self->dbi->delete(from => 'aliases',     where => { identifier => [ map { $_->db->{identifier} } values %{$certhelper->_certs} ] } );
    $self->dbi->commit;
}

sub _build_dbi {
    my ($self) = @_;

    #Log::Log4perl->easy_init($OFF);
    return OpenXPKI::Server::Database->new(
        log => Log::Log4perl->get_logger(),
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
        type    => "MySQL",
        name    => $ENV{OXI_TEST_DB_MYSQL_NAME},
        host    => $ENV{OXI_TEST_DB_MYSQL_DBHOST},
        port    => $ENV{OXI_TEST_DB_MYSQL_DBPORT},
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

1;

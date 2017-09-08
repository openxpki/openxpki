package OpenXPKI::Test;
use Moose;
use utf8;

=head1 NAME

OpenXPKI::Test - Set up an OpenXPKI test environment.

=head1 SYNOPSIS

To only write the config files into C<$oxitest-E<gt>testenv_root."/etc/openxpki/config.d">:

    my $oxitest = OpenXPKI::Test->new;
    $oxitest->setup_env;

To quickly initialize the default test environment and server:

    my $oxitest = OpenXPKI::Test->new;
    $oxitest->setup_env->init_server;
    # we now have CTX('config'), CTX('log'), CTX('dbi'), CTX('api') and CTX('session')

Or you might want to add some custom workflow config:

    my $oxitest = OpenXPKI::Test->new;
    $oxitest->workflow_config("alpha", wf_type_1 => {
        'head' => {
            'label' => 'Perfect workflow',
            'persister' => 'OpenXPKI',
            'prefix' => 'liar',
        },
        'state' => {
            'INITIAL' => {
                'action' => [ 'initialize > PERSIST' ],
            },
            ...
        }
    );
    $oxitest->setup_env;
    $oxitest->init_server('workflow_factory');
    # we now have CTX('workflow_factory') besides the default ones

=cut

# Core modules
use Data::Dumper;
use File::Temp qw( tempdir );

# CPAN modules
use Moose::Exporter;
use Log::Log4perl qw(:easy);
use Moose::Util::TypeConstraints;
use Test::Deep::NoTest qw( eq_deeply bag ); # use eq_deeply() without beeing in a test

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

B<Parameters> (these are object attributes and can be accesses as such)

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

=item * I<testenv_root> (optional) - Temporary directory that serves as root
path for the test environment (configuration files etc.). Default: newly created
directory

=cut
has testenv_root => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    default => sub { scalar(tempdir( CLEANUP => 1 )) },
);

=item * I<start_watchdog> (optional) - Set to 1 to start the watchdog when the
test server starts up. Default: 0

=cut
has start_watchdog => (
    is => 'rw',
    isa => 'Int',
    lazy => 1,
    default => 0,
);

=back

=cut

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
            start_watchdog => $self->start_watchdog,
        )
    },
);

# Flag whether setup_env was called
has _env_initialized => ( is => 'rw', isa => 'Bool', default => 0, init_arg => undef );

=head2 setup_env

Set up the test environment.

=over

=item * reads the database configuration,

=item * creates a temporary directory with YAML configuration files,

=back

=cut
sub setup_env {
    my ($self) = @_;

    # Init Log4perl
    $self->_init_screen_log;

    # Write configuration YAML files
    $self->config_writer->create;

    # Store private key files in temp env/dir
    # TODO This is hackish, OpenXPKI::Test::CertHelper::Database needs to store infos about realms as well (be authoritative source about realms/certs for tests)
    for my $alias (keys %{ $self->certhelper_database->private_keys }) {
        my $realm = (split("-", $alias))[0]; die "Could not extract realm from alias $alias" unless $realm;
        $self->config_writer->write_private_key($realm, $alias, $self->certhelper_database->private_keys->{$alias});
    }

    # Create base directory for test configuration
    $ENV{OPENXPKI_CONF_PATH} = $self->testenv_root."/etc/openxpki/config.d"; # so OpenXPKI::Config will access our config from now on

    $self->_env_initialized(1);

    return $self;
}

=head2 init_server

Initializes the basic context objects:

    C<CTX('config')>
    C<CTX('log')>
    C<CTX('dbi')>
    C<CTX('api')>
    C<CTX('session')>

Note that C<CTX('session')-E<gt>data-E<gt>pki_realm> will return the first realm
specified in L<OpenXPKI::Test::ConfigWriter/realms>.

B<Parameters>

=over

=item * I<@additional_tasks> (optional) - list of additional server tasks to
intialize (they will be passed on to L<OpenXPKI::Server::Init/init>).

=back

=cut
sub init_server {
    my ($self, @additional_tasks) = @_;

    die "setup_env() must be called before init_server()" unless $self->_env_initialized;

    # Init basic CTX objects
    my @tasks = qw( config_versioned log dbi_log dbi api authentication ); # our default tasks
    my %task_hash = map { $_ => 1 } @tasks;
    push @tasks, grep { not $task_hash{$_} } @additional_tasks; # more tasks requested via parameter
    OpenXPKI::Server::Init::init({ TASKS  => \@tasks, SILENT => 1, CLI => 0 });

    # Set session separately (OpenXPKI::Server::Init::init "killed" any old one)
    my $session = OpenXPKI::Server::Session->new(load_config => 1)->create;
    OpenXPKI::Server::Context::setcontext({'session' => $session, force => 1});
    # set PKI realm after init() as various init procedures overwrite the realm
    $session->data->pki_realm($self->config_writer->realms->[0]);

    return $self;
}


=head2 realm_config

Add another YAML configuration file for the given realm and reload server
config C<CTX('config')>.

Example:

    $oxitest->realm_config(
        "alpha",
        "auth.handler.Signature" => {
            realm => [ "alpha" ],
            cacert => [ "MyCertId" ],
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

B<Parameters>

=over

=item * I<$realm> - PKI realm

=item * I<$config_path> - dot separated config path below C<realm.xxx> where
to store the configuration

=item * I<$yaml_hash> - I<HashRef> with configuration data that will be
converted into YAML and stored on disk

=back

=cut
sub realm_config {
    my ($self, $realm, $config_relpath, $yaml_hash) = @_;
    my $config_path = "realm.$realm.$config_relpath";
    $self->config_writer->add_user_config($config_path => $yaml_hash);
}

=head2 workflow_config

Add a workflow definition and reload server config C<CTX('config')>.

Example:

    $oxitest->workflow_config(
        "alpha",
        set_motd => {
            head => {
                prefix    => "motd",
                persister => "Volatile",
                label     => "I18N_OPENXPKI_UI_WF_TYPE_MOTD_LABEL",
            },
            state => {
                INITIAL => {
                    ...
                },
            },
            ....
        },
    );

This would write the following content into
I<etc/openxpki/config.d/realm/alpha.yaml> (below
C<$oxitest-E<gt>testenv_root>):

    ...
    def:
      set_motd:
        head:
          prefix: motd
          persister: Volatile
          label: I18N_OPENXPKI_UI_WF_TYPE_MOTD_LABEL

        state:
          INITIAL:
    ...

B<Parameters>

=over

=item * I<$realm> - PKI realm

=item * I<$name> - name of the workflow to be added below C<realm.xxx.workflow.def>

=item * I<$yaml_hash> - I<HashRef> with configuration data that will be
converted into YAML and stored on disk

=back

=cut
sub workflow_config {
    my ($self, $realm, $name, $yaml_hash) = @_;
    $self->realm_config($realm, "workflow.def.$name" => $yaml_hash);
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

=head2 get_default_realm

Returns the name of the default realm in the test environment that can be used
in test code.

=cut
sub get_default_realm {
    my ($self) = @_;
    return $self->config_writer->realms->[0];
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

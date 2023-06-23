package OpenXPKI::Server::Init;

use strict;
use warnings;

# Core modules
use English;
use Errno;

# CPAN modules
use Log::Log4perl;
use Scalar::Util qw( blessed );

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::i18n qw(set_language set_locale_prefix);
use OpenXPKI::Exception;

use OpenXPKI::Config;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::Server::Database; # PLEASE NOTE: this enables all warnings via Moose::Exporter
use OpenXPKI::Server::Log;
use OpenXPKI::Server::Log::CLI;
use OpenXPKI::Server::API2;
use OpenXPKI::Server::Authentication;
use OpenXPKI::Server::Notification::Handler;
use OpenXPKI::Workflow::Handler;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Bedroom;
use OpenXPKI::Metrics;

use Feature::Compat::Try; # should be done after other imports to safely disable warnings

# define an array of hash refs mapping the task id to the corresponding
# init code. the order of the array elements is also the default execution
# order.
my @INIT_TASKS = qw(
  config_versioned
  i18n
  log
  redirect_stderr
  prepare_daemon
  dbi
  dbi_log
  crypto_layer
  metrics
  api2
  workflow_factory
  volatile_vault
  authentication
  notification
  server
  bedroom
  terminal
);
#

my %IS_INITIALIZED;
sub reset { %IS_INITIALIZED = map { $_ => 0 } @INIT_TASKS }
OpenXPKI::Server::Init::reset(); # there is also CORE::reset() so we need the package prefix

# holds log statements until the logging subsystem has been initialized
my @log_queue;

sub init {
    my $keys = shift;

    # TODO Rework this: we create a temporary in-memory session to allow access to realm parts of the config
    OpenXPKI::Server::Context::setcontext({
        'session' => OpenXPKI::Server::Session->new(type => "Memory")->create()
    }) unless OpenXPKI::Server::Context::hascontext('session');

    log_wrapper("OpenXPKI initialization") unless $keys->{SILENT};

    my @tasks;

    if (defined $keys->{TASKS} && (ref $keys->{TASKS} eq 'ARRAY')) {
        @tasks = @{$keys->{TASKS}};
    } elsif ($keys->{SKIP}) {
        my %skip = map {$_=>1} @{$keys->{SKIP}};
        @tasks = grep { !$skip{$_} } @INIT_TASKS;
        delete $keys->{SKIP};
    } else {
        @tasks = @INIT_TASKS;
    }

    delete $keys->{TASKS};

    foreach my $task (@tasks) {
        ##! 16: 'task: ' . $task
        if (! exists $IS_INITIALIZED{$task}) {
            OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_TASK_ILLEGAL_TASK_ACTION",
            params  => {
                task => $task,
            });
        }
        next if $IS_INITIALIZED{$task};

        ##! 16: 'do_init_' . $task
        log_wrapper("Initialization task '$task'") unless $keys->{SILENT};

        # call init function
        try {
            my $func = \&{ __PACKAGE__."::__do_init_$task" };
            $func->($keys);
        }
        catch ($err) {
            if (blessed $err and $err->isa('OpenXPKI::Exception')) {
                my $msg = $err->message || '<no message>';
                log_wrapper("Error during initialization task '$task': $msg", "fatal");
                $err->rethrow;
            } else {
                log_wrapper("Error during initialization task '$task': $err", "fatal");
                OpenXPKI::Exception->throw(
                    message => "I18N_OPENXPKI_SERVER_INIT_TASK_INIT_FAILURE",
                    params  => { task => $task, ERROR => $err },
                );
            }
        }

        $IS_INITIALIZED{$task}++;

        log_wrapper("Initialization task '$task' finished", "debug") unless $keys->{SILENT};
    }

    log_wrapper("OpenXPKI initialization finished") unless $keys->{SILENT};

    OpenXPKI::Server::Context::killsession();

    return 1;
}

sub log_wrapper {
    my $msg = shift;
    my $prio = shift || 'info';

    if ($IS_INITIALIZED{'log'}) {
        if (scalar @log_queue) {
            foreach my $entry (@log_queue) {
                my $msg = $entry->[0];
                my $prio = $entry->[1];
                CTX('log')->system->$prio($msg);
            }
            @log_queue = ();
        }
        CTX('log')->system->$prio($msg);
    } else {
        # log system not yet prepared, queue log statement
        push @log_queue, [$msg, $prio];
    }
    return 1;
}

sub get_remaining_init_tasks {
    my @remaining_tasks = map { not $IS_INITIALIZED{$_} } @INIT_TASKS;
    return @remaining_tasks;
}

sub get_init_tasks {
    return @INIT_TASKS;
}

###########################################################################
# init functions to be called during init task processing

sub __do_init_workflow_factory {
    my $keys = shift;
    ##! 1: 'init workflow factory'
    my $workflow_factory = OpenXPKI::Workflow::Handler->new();
    $workflow_factory->load_default_factories;

    OpenXPKI::Server::Context::setcontext({
        'workflow_factory' => $workflow_factory
    });
}

sub __do_init_config_versioned {
    ##! 1: "init config"
    my $config = OpenXPKI::Config->new();

    OpenXPKI::Server::Context::setcontext({
        'config' => $config
    });
}

sub __do_init_i18n {
    ##! 1: "init i18n"
    my $prefix = CTX('config')->get('system.server.i18n.locale_directory')
        or OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_LOCALE_DIRECTORY_MISSING',
        );
    my $language = CTX('config')->get('system.server.i18n.default_language') || 'C';

    set_locale_prefix($prefix);
    set_language($language);

    binmode STDOUT, ":utf8";
    binmode STDIN,  ":utf8";
}

sub __do_init_log {
    my $keys = shift;
    ##! 1: "init log"
    my $log;

    if ($keys->{CLI}) {
        ##! 16 'use cli logger'
        $log = OpenXPKI::Server::Log::CLI->new();
    } else {
        ##! 16 'use server logger'
        $log = get_log();
    }

    OpenXPKI::Server::Context::setcontext({
        'log' => $log
    });
    ##! 64: 'log during init: ' . ref $log
}


sub __do_init_prepare_daemon {
    ##! 1: "init prepare daemon"

    # create new session
    POSIX::setsid or die "unable to create new session!: $!";

    # prepare daemonizing myself
    # redirect filehandles
    open STDOUT, ">/dev/null" or die "unable to write to /dev/null!: $!";
    open STDIN, "/dev/null" or die "unable to read from /dev/null!: $!";

    chdir '/';

    # we redirect stderr to our debug log file, so don't do it here:
    # open STDERR, '>&STDOUT' or
    # die "unable to attach STDERR to STDOUT!: $!";
}

sub __do_init_crypto_layer {
    ##! 1: "init crypto layer"
    OpenXPKI::Server::Context::setcontext({
        'crypto_layer' => get_crypto_layer()
    });
}

sub __do_init_redirect_stderr {
    ##! 1: "init stderr redirection"
    my $stderr = CTX('config')->get('system.server.stderr')
        or OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_MISSING_STDERR"
        );
    ##! 2: "redirecting STDERR to $stderr"
    open STDERR, '>>', $stderr
        or OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_FAILED"
        );
    binmode STDERR, ":utf8";
}

sub __do_init_volatile_vault {
    ##! 1: "init volatile vault"
    my $token = CTX('api2')->get_default_token();
    my $vault = OpenXPKI::Crypto::VolatileVault->new({ TOKEN => $token });

    OpenXPKI::Server::Context::setcontext({
        'volatile_vault' => $vault
    });
}

sub __do_init_dbi_log {
    ##! 1: "init dbi log"
    OpenXPKI::Server::Context::setcontext({
        'dbi_log' => get_database("log")
    });
}

# TODO #legacydb Add delete(from => "secret", all => 1) either here or in separate init function
sub __do_init_dbi {
    ##! 1: "init dbi"
    my $keys = shift;
    # enforce autocommit for init from CLI script
    OpenXPKI::Server::Context::setcontext({
        'dbi' => get_database("main", ($keys->{CLI} ? 1 : 0) )
    });
}

sub __do_init_acl {
    ##! 1: "init acl"
    OpenXPKI::Server::Context::setcontext({
        'acl' => 1
    });
}

sub __do_init_api {
    warn "API v1 does no longer exist";
}

sub __do_init_api2 {
    ##! 1: "init api2"
    my $api = OpenXPKI::Server::API2->new(
        enable_acls => 0,
        # acl_rule_accessor => sub { CTX('config')->get_hash('acl.rules.' . CTX('session')->data->role ) },
        log => CTX('log')->system,
    );

    OpenXPKI::Server::Context::setcontext({
        'api2' => $api->autoloader
    });
}

sub __do_init_authentication {
    ##! 1: "init authentication"
    my $obj = OpenXPKI::Server::Authentication->new()
        or OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DO_INIT_AUTHENTICATION_INSTANTIATION_FAILURE"
        );

    OpenXPKI::Server::Context::setcontext({
        'authentication' => $obj
    });
}

sub __do_init_server {
    my $keys = shift;
    ##! 1: "init server"
    ##! 16: '__do_init_server: ' . Dumper($keys)
    return unless defined $keys->{SERVER};

    OpenXPKI::Server::Context::setcontext({
        'server' => $keys->{SERVER}
    });
}

sub __do_init_notification {
    ##! 1: "init notification"
    OpenXPKI::Server::Context::setcontext({
        'notification' => OpenXPKI::Server::Notification::Handler->new()
    });
}

sub __do_init_bedroom {
    ##! 1: "init bedroom"
    OpenXPKI::Server::Context::setcontext({
        'bedroom' => OpenXPKI::Server::Bedroom->new()
    });
}

sub __do_init_terminal {
    try {
        # this is EE code:
        require OpenXPKI::Server::ProcTerminal;
    }
    catch ($err) {
        if ($err =~ m{locate OpenXPKI/Server/ProcTerminal\.pm in \@INC}) {
            log_wrapper("NOT initializing 'terminal' - EE class not found");
            return;
        }
        die $err;
    }

    my $config = CTX('config')->get_hash('system.terminal') // {};

    my $manager = OpenXPKI::Server::ProcTerminal->new(
        OpenXPKI::Server::Context::hascontext('log')
            ? (log => CTX('log')->system)
            : (),
        config => $config,
    );

    OpenXPKI::Server::Context::setcontext({
        'terminal' => $manager
    });
}

sub __do_init_metrics {
    my $enabled = CTX('config')->get('system.metrics.enabled') ? 1 : 0;
    my $cache_dir = CTX('config')->get('system.metrics.cache_dir') // '/var/tmp/openxpki.metrics';
    my $cache_user = CTX('config')->get('system.server.user');
    my $cache_group = CTX('config')->get('system.server.group');

    my $metrics = OpenXPKI::Metrics->new(
        enabled => $enabled,
        cache_dir => $cache_dir,
        $cache_user ? (cache_user => $cache_user) : (),
        $cache_group ? (cache_group => $cache_group) : (),
    );

    OpenXPKI::Server::Context::setcontext({
        'metrics' => $metrics
    });
}

###########################################################################

sub get_crypto_layer {
    ##! 1: "start"

    my $tmpdir = CTX('config')->get(['system','server','tmpdir']);
    if ($tmpdir) {
        return OpenXPKI::Crypto::TokenManager->new({ TMPDIR => $tmpdir });
    } else {
        return OpenXPKI::Crypto::TokenManager->new();
    }
}

sub get_log {
    ##! 1: "start"
    my $config_file = CTX('config')->get('system.server.log4perl');

    ## init logging
    ##! 64: 'before Log->new'

    my $log = OpenXPKI::Server::Log->new (CONFIG => $config_file);

    ##! 64: 'log during get_log: ' . $log

    return $log;
}

sub get_database {
    my ($section, $autocommit) = @_;

    # enforce autocommit on the log handle if not explicitly disabled
    if ($section eq 'log' && !defined $autocommit){
        $autocommit = 1;
    }

    ##! 1: "start"

    #
    # Read DB config
    #
    my $config = CTX('config');
    # Fallback for logger/audit configs which can be separate

    $section = 'main' unless $config->exists(['system','database',$section]);
    my $db_config = $config->get_hash(['system','database',$section]);

    my $wait_on_init = {};
    if ($db_config->{wait_on_init} && ref $db_config->{wait_on_init} eq 'HASH') {
        $wait_on_init = $db_config->{wait_on_init};
        delete $db_config->{wait_on_init};
    }

    # Set environment variables
    my $db_env = $config->get_hash(['system','database','environment']);

    if (!$db_env && $db_config->{environment}) {
        $db_env = $config->get_hash(['system','database',$section,'environment']);
        delete $db_config->{environment};
        Log::Log4perl->get_logger('openxpki.deprecated')->info('Please move your database environment config to database.environment');
    }

    for my $env_name (keys %{$db_env}) {
        $ENV{$env_name} = $db_env->{$env_name};
        ##! 4: "DBI Environment: $env_name => ".$db_env->{$env_name}
    }

    # TODO #legacydb Remove treatment of DB parameters "debug" and "log" (occurs in example database.yaml)
    delete $db_config->{log};
    delete $db_config->{debug};

    my $db = OpenXPKI::Server::Database->new(
        # if this DB object should be used for logging: we prevent recursive
        # calls to log functions in OpenXPKI::Server::Log::Appender::Database
        log => CTX('log')->system(),
        db_params => {
            db_type => 'MySQL', # default
            %{ $db_config },
        },
        $autocommit ? (autocommit => 1) : (),
    );

    my $retry = $wait_on_init->{retry_count} // 0;
    my $sleep = $wait_on_init->{retry_interval} || 30;

    # do a database ping to ensure the DB is connected
    # sleep / retry if configured
    ##! 32: "database retry setting: ${retry}x / ${sleep}s"

    do {
        eval{
            $db->ping();
            $retry = 0;
        };
        if ($EVAL_ERROR) {
            if ($retry) {
                print STDERR "Database not ready - retries left $retry - sleep for $sleep\n";
                sleep $sleep;
            } else {
                OpenXPKI::Exception->throw ( message => "Database not connected", params => { error => $EVAL_ERROR } );
            }
        }
    } while ($retry--);
    return $db;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Init - daemon initialization

=head1 Description

This class is used to initialize all the objects which are required. The
code is not in the server class itself to get a clean interface for the
initialization and to avoid any "magic" stuff. We hope that this makes
the customization of the code more easier.

=head1 Functions

=head2 Basic Initialization

=head3 init

Initialization must be done ONCE by the server process.
Expects the XML configuration file via the named parameter CONFIG.

Usage:

  use OpenXPKI::Server::Init;

  OpenXPKI::Server::Init::init({
         CONFIG => 't/config.xml',
     });

If called this way, the init code processes all initialization steps.
You may split the initialization sequence in order to do stuff in
between steps by providing an array reference TASKS as a named argument:

  OpenXPKI::Server::Init::init({
         CONFIG => 't/config.xml',
         TASKS  => [ 'config', 'i18n', 'log' ],
     });

and later simply call

  OpenXPKI::Server::Init::init({
         CONFIG => 't/config.xml',
     });

to initialize the remaining tasks.

If called without the TASKS argument the function will perform all steps
that were not already executed before.

If called with the named argument SILENT set to a true value the
init method does not log successful initialization steps.

=head3 get_remaining_init_tasks

Returns an array of all remaining initialization task names (i. e. all
tasks that have not yet been executed) in the order they would normally
be processed.

=head3 get_workflow_factory

Returns a workflow factory which already has the configuration added
from the configuration files and is ready for use.

=head3 get_config

expects as only parameter the option CONFIG. This must be a filename
of an XML configuration file which is compliant with OpenXPKI's schema
definition in openxpki.xsd. We support local xinclude so please do not
be surprised if you habe a configuration file which looks a little bit
small. It returns an instance of OpenXPKI::XML::Config.

=head3 reset

Resets the initialization state.

Used to re-initialize the server in tests.

=head2 Cryptographic Initialization

=head3 get_crypto_layer

Return an instance of the TokenManager class which handles all
configured cryptographic tokens.

=head2 Non-Cryptographic Object Initialization

=head3 get_log

Returns an instance of the module OpenXPKI::Log.

Requires 'config' in the Server Context.

=head3 get_database

Returns an instance of the L<OpenXPKI::Server::Database>.

A section name must be given below the config path I<system.database>.

Requires 'log' in the Server Context.

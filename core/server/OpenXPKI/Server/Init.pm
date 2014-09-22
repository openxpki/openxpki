## OpenXPKI::Server::Init.pm
##
## Written by Michael Bell for the OpenXPKI project 2005
## Copyright (C) 2005 by The OpenXPKI Project

package OpenXPKI::Server::Init;

use strict;
use warnings;
use utf8;

## used modules

# use Smart::Comments;

use English;
use Errno;
use OpenXPKI::Debug;
use OpenXPKI::i18n qw(set_language set_locale_prefix);
use OpenXPKI::Exception;

use OpenXPKI::Config;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::Server;
use OpenXPKI::Server::DBI;
use OpenXPKI::Server::Log;
use OpenXPKI::Server::Log::NOOP;
use OpenXPKI::Server::Log::CLI;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Authentication;
use OpenXPKI::Server::Notification::Handler;
use OpenXPKI::Workflow::Handler;
use OpenXPKI::Server::Watchdog;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Session::Mock;

use OpenXPKI::Crypto::X509;

use OpenXPKI::Serialization::Simple;
use OpenXPKI::Serialization::Fast;

use Data::Dumper;

use Test::More;

use Digest::SHA qw( sha1_base64 );

# define an array of hash refs mapping the task id to the corresponding
# init code. the order of the array elements is also the default execution
# order.
my @init_tasks = qw(
  config_versioned
  config_test
  i18n
  dbi_log
  log
  redirect_stderr
  prepare_daemon
  dbi_backend
  dbi_workflow
  crypto_layer
  api
  workflow_factory
  volatile_vault
  authentication
  notification
  server
  watchdog
);
#

my %is_initialized = map { $_ => 0 } @init_tasks;


# holds log statements until the logging subsystem has been initialized
my @log_queue;

sub init {
    my $keys = shift;

    # We need a valid session to access the realm parts of the config
    if (!OpenXPKI::Server::Context::hascontext('session')) {
        my $session = OpenXPKI::Server::Session::Mock->new();
        OpenXPKI::Server::Context::setcontext({'session' => $session});
    }

    if (! (exists $keys->{SILENT} && $keys->{SILENT})) {
    log_wrapper(
        {
        MESSAGE  => "OpenXPKI initialization",
        PRIORITY => "info",
        FACILITY => "system",
        });
    }

    my @tasks;

    if (defined $keys->{TASKS} && (ref $keys->{TASKS} eq 'ARRAY')) {
    @tasks = @{$keys->{TASKS}};
    } else {
    @tasks = @init_tasks;
    }

    delete $keys->{TASKS};



  TASK:
    foreach my $task (@tasks) {
        ##! 16: 'task: ' . $task
    if (! exists $is_initialized{$task}) {
        OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_SERVER_INIT_TASK_ILLEGAL_TASK_ACTION",
        params  => {
            task => $task,
        });
    }
    next TASK if $is_initialized{$task};

    ##! 16: 'do_init_' . $task
    if (! (exists $keys->{SILENT} && $keys->{SILENT})) {
        log_wrapper(
        {
            MESSAGE  => "Initialization task '$task'",
            PRIORITY => "info",
            FACILITY => "system",
        });
    }

    eval "__do_init_$task(\$keys);";
    if (my $exc = OpenXPKI::Exception->caught())
    {
        my $msg = $exc->message() || '<no message>';
        log_wrapper(
        {
            MESSAGE  => "Exception during initialization task '$task': " . $msg,
            PRIORITY => "fatal",
            FACILITY => "system",
        });
        print "Exception during initialization task '$task': " . $msg;
        $exc->rethrow();
    }
    elsif ($EVAL_ERROR)
    {
        my $error = $EVAL_ERROR;
        log_wrapper({
            MESSAGE  => "Eval error during initialization task '$task': " . $error,
            PRIORITY => "fatal",
            FACILITY => "system",
        });

        OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_SERVER_INIT_TASK_INIT_FAILURE",
        params  => {
            task => $task,
            EVAL_ERROR => $error,
        });
    }

    $is_initialized{$task}++;

    # suppress informational output if SILENT is specified
    if (! (exists $keys->{SILENT} && $keys->{SILENT})) {
        log_wrapper(
        {
            MESSAGE  => "Initialization task '$task' finished",
            PRIORITY => "debug",
            FACILITY => "system",
        });
    }
    }

    if (! (exists $keys->{SILENT} && $keys->{SILENT})) {
    log_wrapper(
        {
        MESSAGE  => "OpenXPKI initialization finished",
        PRIORITY => "info",
        FACILITY => "system",
        });
    }

    OpenXPKI::Server::Context::killsession();

    return 1;
}


sub log_wrapper {
    my $arg = shift;

    if ($is_initialized{'log'}) {
    if (scalar @log_queue) {
        foreach my $entry (@log_queue) {
        CTX('log')->log(
            %{$entry},
            );
        }
        @log_queue = ();
    }
    CTX('log')->log(
        %{$arg},
        );
    } else {
    # log system not yet prepared, queue log statement
    push @log_queue, $arg;
    }
    return 1;
}


sub get_remaining_init_tasks {
    my @remaining_tasks;

    foreach my $task (@init_tasks) {
    if (! $is_initialized{$task}) {
        push @remaining_tasks, $task;
    }
    }

    return @remaining_tasks;
}



###########################################################################
# init functions to be called during init task processing

sub __do_init_workflow_factory {
    my $keys = shift;
    ##! 1: 'init workflow factory'

    my $workflow_factory = OpenXPKI::Workflow::Handler->new();
    $workflow_factory->load_default_factories();
    OpenXPKI::Server::Context::setcontext({
        workflow_factory => $workflow_factory,
    });
    return 1;
}

sub __do_init_config_versioned {
    ##! 1: "init OpenXPKI config"
    my $config = OpenXPKI::Config->new();
    OpenXPKI::Server::Context::setcontext(
    {
        config => $config,
    });
    # Otherwise the init all routine tries to instantiate the test config
    $is_initialized{config_test} = 1;
    return 1;
}


# Special init for test cases
sub __do_init_config_test {
    ##! 1: "init OpenXPKI config"
    require OpenXPKI::Config::Test;
    my $xml_config = OpenXPKI::Config::Test->new();
    OpenXPKI::Server::Context::setcontext(
    {
        config => $xml_config,
    });
    return 1;
}

sub __do_init_i18n {
    ##! 1: "init i18n"
    init_i18n();
}

sub __do_init_log {
    ##! 1: "init log"

    my $keys = shift;

    my $log;

    if ($keys->{CLI}) {
        ##! 16 'use cli logger'
        $log = OpenXPKI::Server::Log::CLI->new();
    } else {
        ##! 16 'use server logger'
        $log = get_log();
    }

    ### $log
    OpenXPKI::Server::Context::setcontext(
    {
        log => $log,
    });
    ##! 64: 'log during init: ' . ref $log
}


sub __do_init_prepare_daemon {
    ##! 1: "init prepare daemon"

    # create new session
    POSIX::setsid or
    die "unable to create new session!: $!";

    # prepare daemonizing myself
    # redirect filehandles
    open STDOUT, ">/dev/null" or
    die "unable to write to /dev/null!: $!";
    open STDIN, "/dev/null" or
    die "unable to read from /dev/null!: $!";

    chdir '/';

    # we redirect stderr to our debug log file, so don't do it here:
    # open STDERR, '>&STDOUT' or
    # die "unable to attach STDERR to STDOUT!: $!";
}

sub __do_init_crypto_layer {
    ##! 1: "init crypto layer"
    OpenXPKI::Server::Context::setcontext(
    {
        crypto_layer => get_crypto_layer(),
    });
}

sub __do_init_redirect_stderr {
    ##! 1: "init stderr redirection"
    redirect_stderr();
}

sub __do_init_volatile_vault {
    ##! 1: "init volatile vault"

    my $token = CTX('api')->get_default_token();

    if (! defined $token) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DO_INIT_VOLATILEVAULT_MISSING_TOKEN");
    }

    OpenXPKI::Server::Context::setcontext(
    {
        volatile_vault => OpenXPKI::Crypto::VolatileVault->new(
        {
            TOKEN => $token,
        }),
    });
}

sub __do_init_dbi_backend {
    ### init backend dbi...
    my $dbi = get_dbi(
    {
        PURPOSE => 'backend',
    });

    OpenXPKI::Server::Context::setcontext(
    {
        dbi_backend => $dbi,
    });
    # delete leftover secrets
    CTX('dbi_backend')->connect();
    CTX('dbi_backend')->delete(
        TABLE => 'SECRET',
        ALL   => 1,
    );
    CTX('dbi_backend')->commit();
    CTX('dbi_backend')->disconnect();
}

sub __do_init_dbi_workflow {
    ### init backend dbi...
    my $dbi = get_dbi(
    {
        PURPOSE => 'workflow',
    });

    OpenXPKI::Server::Context::setcontext(
    {
        dbi_workflow => $dbi,
    });
}

sub __do_init_dbi_log {
    ### init backend dbi...
    my $dbi = get_dbi(
    {
        PURPOSE => 'log',
    });

    OpenXPKI::Server::Context::setcontext(
    {
        dbi_log => $dbi,
    });
    CTX('dbi_log')->connect();
}


sub __do_init_acl {
    ### init acl...
    OpenXPKI::Server::Context::setcontext(
    {
        acl => 1
    });
}

sub __do_init_api {
    ### init api...
    OpenXPKI::Server::Context::setcontext(
    {
        api => OpenXPKI::Server::API->new(),
    });
}

sub __do_init_authentication {
    ### init authentication...
    my $obj = OpenXPKI::Server::Authentication->new();
    if (! defined $obj) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DO_INIT_AUTHENTICATION_INSTANTIATION_FAILURE");
    }
    OpenXPKI::Server::Context::setcontext(
    {
        authentication => $obj,
    });
}

sub __do_init_server {
    my $keys = shift;
    ### init server ref...
    ##! 16: '__do_init_server: ' . Dumper($keys)
    if (defined $keys->{SERVER}) {
    OpenXPKI::Server::Context::setcontext(
        {
        server => $keys->{SERVER},
        });
    }
}

sub __do_init_notification {
    OpenXPKI::Server::Context::setcontext({
        notification => OpenXPKI::Server::Notification::Handler->new(),
    });
    return 1;
}

sub __do_init_watchdog{
    my $keys = shift;

    my $config = CTX('config');

    my $Watchdog = OpenXPKI::Server::Watchdog->new( {
        user => OpenXPKI::Server::__get_numerical_user_id( $config->get('system.server.user') ),
        group => OpenXPKI::Server::__get_numerical_group_id( $config->get('system.server.group') )
    } );

    $Watchdog->run() unless ( $config->get('system.watchdog.disabled') );

    OpenXPKI::Server::Context::setcontext({
        watchdog => $Watchdog
    });
    return 1;
}


###########################################################################

sub init_i18n
{
    my $keys = { @_ };
    ##! 1: "start"

    my $prefix = CTX('config')->get('system.server.i18n.locale_directory');
    if (!$prefix) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_LOCALE_DIRECTORY_MISSING',
        );
    }
    my $language = CTX('config')->get('system.server.i18n.default_language') || 'C';

    set_locale_prefix ($prefix);
    set_language      ($language);

    binmode STDOUT, ":utf8";
    binmode STDIN,  ":utf8";

    return 1;
}


sub get_crypto_layer
{
    ##! 1: "start"

    return OpenXPKI::Crypto::TokenManager->new();
}

sub get_dbi
{
    my $args = shift;

    ##! 1: "start"

    my $xml_config = CTX('config');
    my %params;

    my $dbpath = 'system.database.main';
    if (exists $args->{PURPOSE} && $args->{PURPOSE} eq 'log') {
        ##! 16: 'purpose: log'
        # if there is a logging section we use it
        if ($xml_config->exists('system.database.logging')) {
            ##! 16: 'use logging section'
            $dbpath = 'system.database.logging';
        }
        %params = (LOG => OpenXPKI::Server::Log::NOOP->new());
    }
    else {
        %params = (LOG => CTX('log'));
    }

    my $db_config = $xml_config->get_hash($dbpath);

    foreach my $key (qw(type name namespace host port user passwd)) {
        ##! 16: "dbi: $key => " . $db_config->{$key}
        $params{uc($key)} = $db_config->{$key};
    }

   $params{SERVER_ID} = $xml_config->get('system.server.node.id');
   $params{SERVER_SHIFT} = $xml_config->get('system.server.shift');

    # environment
    my @env_names = $xml_config->get_keys("$dbpath.environment");

    foreach my $env_name (@env_names) {
        my $env_value = $xml_config->get_keys("$dbpath.environment.$env_name");
        $ENV{$env_name} = $env_value;
        ##! 4: "DBI Environment: $env_name => $env_value"
    }

    # special handling for SQLite databases
    if ($params{TYPE} eq "SQLite") {
        if (defined $args->{PURPOSE} && ($args->{PURPOSE} ne "")) {
            $params{NAME} .= "._" . $args->{PURPOSE} . "_";
            ##! 16: 'SQLite, name: ' . $params{NAME}
        }
    }

    return OpenXPKI::Server::DBI->new (%params);
}

sub get_log
{
    ##! 1: "start"
    my $config_file = CTX('config')->get('system.server.log4perl');

    ## init logging
    ##! 64: 'before Log->new'

    my $log = OpenXPKI::Server::Log->new (CONFIG => $config_file);

    ##! 64: 'log during get_log: ' . $log

    return $log;
}

sub redirect_stderr
{
    ##! 1: "start"
    my $stderr = CTX('config')->get('system.server.stderr');
    if (not $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_MISSING_STDERR");
    }
    ##! 2: "redirecting STDERR to $stderr"
    if (not open STDERR, '>>', $stderr)
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_REDIRECT_STDERR_FAILED");
    }
    binmode STDERR, ":utf8";
    return 1;
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
         TASKS  => [ 'xml_config', 'i18n', 'log' ],
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

=head3 get_xml_config

expects as only parameter the option CONFIG. This must be a filename
of an XML configuration file which is compliant with OpenXPKI's schema
definition in openxpki.xsd. We support local xinclude so please do not
be surprised if you habe a configuration file which looks a little bit
small. It returns an instance of OpenXPKI::XML::Config.

=head3 init_i18n

Initializes the code for internationalization. It requires an instance
of OpenXPKI::XML::Config in the parameter CONFIG.

=head2 Cryptographic Initialization

=head3 get_crypto_layer

Return an instance of the TokenManager class which handles all
configured cryptographic tokens.

=head3 get_pki_realms

Prepares a hash which has the following structure.

$hash{PKI_REALM_NAME}->{"crypto"}->{"default"}

Requires 'xml_config', 'log' and 'crypto_layer' in the Server Context.

The hash also includes validity information as defined in the configuration
in the following sample format:

  $hash{PKI_REALM_NAME} = {
      endentity => {
          id => {
              'User' => {
                  validity => {
                      notafter => {
                          format => 'relativedate',
                          validity => '+0006',
                      },
                  },
              },
          },
      },
      crl => {
          id => {
              'default' => {
                  validity => {
                      notafter => {
                          format => 'relativedate',
                          validity => '+000014',
                      },
                  },
              },
          },
      },
      ca => {
          id => {
              CA1 => {
                  status = 1,    # (0: unavailable, 1: available)
                  identifier => 'ABCDEFGHIJK',
                  crypto => OpenXPKI::Crypto::TokenManager->new(...),
                  cacert => OpenXPKI::Crypto::X509->new(...),
                  notbefore => DateTime->new(),
                  notafter => DateTime->new(),
              },
          },
      },
  };

See OpenXPKI::DateTime for more information about the various time formats
used here.
Undefined 'notbefore' dates are interpreted as 'now' during issuance.
Relative notafter dates relate to the corresponding notbefore date.

Two sections are contained in the hash: 'endentity' and 'crl'
The ID of endentity validities is the corresponding role (profile).
The ID of CRL validities is the internal CA name.


=head2 Non-Cryptographic Object Initialization

=head3 get_dbi

Initializes the database interface and returns the database object reference.

Requires 'log' and 'xml_config' in the Server Context.

If database type is SQLite and the named parameter 'PURPOSE' exists,
this parameter is appended to the SQLite database name.
This is necessary because of a limitation in SQLite that prevents multiple
open transactions on the same database.

=head3 get_log

Returns an instance of the module OpenXPKI::Log.

Requires 'xml_config' in the Server Context.

=head3 get_log

requires no arguments.
It returns an instance of the module OpenXPKI::Server::Authentication.
The context must be already established because OpenXPKI::XML::Config is
loaded from the context.

=head3 redirect_stderr

requires no arguments and is a simple function to send STDERR to
configured file. This is useful to track all warnings and errors.

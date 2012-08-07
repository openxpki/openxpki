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
use OpenXPKI::XML::Config;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::Server::DBI;
use OpenXPKI::Server::Log;
use OpenXPKI::Server::Log::NOOP;
use OpenXPKI::Server::ACL;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Authentication;
use OpenXPKI::Server::Notification::Dispatcher;
use OpenXPKI::Workflow::Factory;
use OpenXPKI::Server::Watchdog;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Session::Mock;
                
use OpenXPKI::Crypto::X509;

use OpenXPKI::Serialization::Simple;
use OpenXPKI::Serialization::Fast;

use Data::Dumper;

use Test::More;

use Digest::SHA1 qw( sha1_base64 );

our $current_xml_config; # this is an OpenXPKI::XML::Config object
                         # containing the current on-disk configuration.
                         # It is needed only during initialization.
                         # (openxpkiadm uses it as a package variable
                         # to access the database configuration during
                         # initdb)

# define an array of hash refs mapping the task id to the corresponding
# init code. the order of the array elements is also the default execution
# order.
my @init_tasks = qw(
  config_versioned
  current_xml_config
  i18n
  dbi_log
  log
  redirect_stderr
  prepare_daemon
  dbi_backend
  dbi_workflow
  xml_config
  workflow_factory
  crypto_layer
  api  
  volatile_vault
  acl    
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

    # We need a valid session to access the realm parts of the config 
    my $session = OpenXPKI::Server::Session::Mock->new();
    OpenXPKI::Server::Context::setcontext({'session' => $session});
    
    
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
    
    my $workflow_factory = get_workflow_factory();
    OpenXPKI::Server::Context::setcontext({
        workflow_factory => $workflow_factory,
    });
    return 1;
}

sub __do_init_current_xml_config {
    my $keys = shift;
    ##! 1: 'init current xml config'
    $current_xml_config = get_current_xml_config(
        CONFIG => $keys->{'CONFIG'},
    );
    return 1;
}

sub __do_init_config_versioned {
    ##! 1: "init OpenXPKI config"
    my $xml_config = OpenXPKI::Config->new();
    OpenXPKI::Server::Context::setcontext(
	{
	    config => $xml_config,
	});
    return 1;
}

sub __do_init_xml_config {
    ##! 1: "init xml config"
    my $xml_config = get_xml_config();
    OpenXPKI::Server::Context::setcontext(
	{
	    xml_config => $xml_config,
	});
    return 1;
}

sub __do_init_i18n {
    ##! 1: "init i18n"
    init_i18n(CONFIG => $current_xml_config);
}

sub __do_init_log {
    ##! 1: "init log"
    my $log          = get_log();
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
    
    # FIXME: if we change to / the daemon works properly in production but
    # our tests fail (because there are a lot of relative path names in the
    # test configuration).
    # FIXME RECONSIDER uncommenting this in the future.
    # chdir '/';

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
	    acl => OpenXPKI::Server::ACL->new({
            CONFIG_ID => 'default',
        }),
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
    my $obj = OpenXPKI::Server::Authentication->new({
        CONFIG_ID => 'default',
    });
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
        notification => OpenXPKI::Server::Notification::Dispatcher->new({
            CONFIG_ID => 'default',
        }),
    });
    return 1;
}

sub __do_init_watchdog{
    my $keys = shift;
    
    my $Watchdog = OpenXPKI::Server::Watchdog->new( $keys );
    $Watchdog->run();    
    OpenXPKI::Server::Context::setcontext({        
        watchdog => $Watchdog
    });
    return 1;    
}


###########################################################################

sub get_workflow_factory {
    ##! 1: 'start'
    my $args  = shift;

     my %workflow_config = (
         # how we name it in our XML configuration file
         workflows => {
             # how the parameter is called for Workflow::Factory 
             factory_param => 'workflow',
             # if this key exists, we assume that no <configfile>
             # is specified but the XML config is included directly
             # and iterate over it to obtain the configuration which
             # we pass to Workflow::Factory->add_config()
             config_key    => 'workflow',
             # the ForceArray XML::Simple option used in Workflow
             # that we have to recreate using __flatten_content()
             # the content is taken from Workflow::Config::XML
             force_array   => [ 'extra_data', 'state', 'action',  'resulting_state', 'condition', 'observer' ],
         },
         activities => {
             factory_param   => 'action',
             config_key      => 'actions',
             # if this key is present, we iterate over two levels:
             # first over all config_keys and then over all
             # config_iterators and add the corresponding structure
             # to the Workflow factory using add_config()
             config_iterator => 'action',
             force_array     => [ 'action', 'field', 'source_list', 'param', 'validator', 'arg' ],
         },
         validators => {
             factory_param   => 'validator',
             config_key      => 'validators',
             config_iterator => 'validator',
             force_array     => [ 'validator', 'param' ],
         },
         conditions => {
             factory_param   => 'condition',
             config_key      => 'conditions',
             config_iterator => 'condition',
             force_array     => [ 'condition', 'param' ],
         },
 	);

    CTX('dbi_backend')->connect();
    my $xml_config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => {VALUE => '%', OPERATOR => "LIKE"},
        },
    );
    CTX('dbi_backend')->disconnect();

    if (! defined $xml_config_entries
        || ref $xml_config_entries ne 'ARRAY'
        || scalar @{ $xml_config_entries } == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_GET_WORKFLOW_FACTORY_NO_CONFIG_IDENTIFIERS_IN_DB',
        );
    }

    my $workflow_factories = {};
    foreach my $xml_config (@{ $xml_config_entries }) {
        my $id = $xml_config->{CONFIG_IDENTIFIER};
        ##! 16: 'id: ' . $id
        my $pki_realm_count = CTX('xml_config')->get_xpath_count(
            XPATH     => "pki_realm",
            CONFIG_ID => $id,
        );
        ##! 16: 'pki_realm_count: ' . $pki_realm_count
        for (my $i = 0; $i < $pki_realm_count; $i++) {
            ##! 16: 'i: ' . $i
            my $realm = CTX('xml_config')->get_xpath(
                XPATH     => [ 'pki_realm', 'name' ],
                COUNTER   => [ $i         , 0      ],
                CONFIG_ID => $id,
            );
            ##! 16: 'realm: ' . $realm
            my $workflow_factory = OpenXPKI::Workflow::Factory->instance();
            ##! 16: 'initialized new and empty WF factory'
            __wf_factory_add_config({
                FACTORY       => $workflow_factory,
                REALM_IDX     => $i,
                CONFIG_ID     => $id,
                WF_CONFIG_MAP => \%workflow_config,
            });
            $workflow_factories->{$id}->{$realm} = $workflow_factory;
            ##! 16: 'added factory for ' . $id . '/' . $realm
        }
    }
    return $workflow_factories;
}

sub __wf_factory_add_config {
    ##! 1: 'start'
    my $arg_ref          = shift;
    my $workflow_factory = $arg_ref->{FACTORY};
    my $idx              = $arg_ref->{REALM_IDX};
    ##! 4: 'idx: ' . $idx
    my $xml_config_id        = $arg_ref->{CONFIG_ID};
    ##! 4: 'config_id: ' . $xml_config_id
    my %workflow_config  = %{ $arg_ref->{WF_CONFIG_MAP} };
    my $xml_config       = CTX('xml_config');

  ADD_CONFIG:
    foreach my $type (qw( conditions validators activities workflows )) {
        ##! 2: "getting workflow '$type' configuration files"
        my $toplevel_count;
        eval {
            $toplevel_count = $xml_config->get_xpath_count(
                XPATH     => [ 'pki_realm'     , 'workflow_config',
                             $type           , $workflow_config{$type}->{config_key} ],
                COUNTER   => [ $idx            , 0,
                             0 ],
                CONFIG_ID => $xml_config_id,
            );
        };
        if (defined $toplevel_count) {
            ##! 16: 'direct XML config exists'
            # we have configuration directly in the XML file, not
            # just a <configfile> reference, use it
            for (my $ii = 0; $ii < $toplevel_count; $ii++) {
                my @base_path = (
                    'pki_realm',
                    'workflow_config',
                    $type,
                    $workflow_config{$type}->{config_key},
                );
                my @base_ctr  = (
                    $idx,
                    0,
                    0,
                    $ii,
                );
                if (exists $workflow_config{$type}->{'config_iterator'}) {
                    # we need to iterate over a second level
                    my $iterator
                        = $workflow_config{$type}->{'config_iterator'};

                    my $secondlevel_count;
                    eval {
                        $secondlevel_count = $xml_config->get_xpath_count(
                            XPATH     => [ @base_path, $iterator ],
                            COUNTER   => [ @base_ctr ],
                            CONFIG_ID => $xml_config_id,
                        );
                    };
                    ##! 16: 'secondlevel_count: ' . $secondlevel_count
                    for (my $iii = 0; $iii < $secondlevel_count; $iii++) {
                        my $entry = $xml_config->get_xpath_hashref(
                            XPATH     => [ @base_path, $iterator ],
                            COUNTER   => [ @base_ctr , $iii      ],
                            CONFIG_ID => $xml_config_id,
                        );
                        ##! 32: 'entry ' . $ii . '/' . $iii . ': ' . Dumper $entry
                        # '__flatten_content()' turns our XMLin
                        # structure into the one compatible to Workflow

                        # Hacking the symbol table ... again.
                        # In add_config(), new Workflow::State objects
                        # are created for every state. Those in turn create
                        # condition objects from the FACTORY. But hell,
                        # not from our factory, but from the factory
                        # obtained using
                        # use Workflow::Factory qw( FACTORY );
                        # this is why we trick Workflow into believing
                        # it is talking to FACTORY, but in fact it is
                        # talking to our factory ...
			no warnings 'redefine';
                        local *Workflow::State::FACTORY = sub { return $workflow_factory };
                        $workflow_factory->add_config(
                            $workflow_config{$type}->{factory_param} =>
                                __flatten_content(
                                    $entry,
                                    $workflow_config{$type}->{'force_array'}
                                ),
                        );
                        ##! 256: 'workflow_factory: ' . Dumper $workflow_factory
                    }
                }
                else {
                    my $entry = $xml_config->get_xpath_hashref(
                        XPATH     => [ @base_path ],
                        COUNTER   => [ @base_ctr  ],
                        CONFIG_ID => $xml_config_id,
                    );
                    ##! 256: "entry: " . Dumper $entry
                    # Flatten some attributes because
                    # Workflow.pm expects these to be scalars and not
                    # a one-element arrayref with a content hashref ...
                    $entry = __flatten_content(
                        $entry,
                        $workflow_config{$type}->{force_array}
                    );
                    ##! 256: 'entry after flattening: ' . Dumper $entry
                    ##! 512: 'workflow_factory: ' . Dumper $workflow_factory
                    # cf. above ...
		    no warnings 'redefine';
                    local *Workflow::State::FACTORY = sub { return $workflow_factory };
                    $workflow_factory->add_config(
                        $workflow_config{$type}->{factory_param} => $entry,
                    );
                    ##! 256: 'workflow_factory: ' . Dumper $workflow_factory
                }
                ##! 16: 'config ' . $ii . ' added to workflow_factory'
            }

            # ignore the <configfile> parsing, we got what we came for
            next ADD_CONFIG;
        }

        # this is now legacy code for parsing the old-style 
        # <configfile> references ...
        my $count;
        eval {
            $count = $xml_config->get_xpath_count(
                XPATH     => [ 'pki_realm', 'workflow_config', $type, 'configfile' ],
                COUNTER   => [ $idx       , 0                , 0 ],
                CONFIG_ID => $xml_config_id,
            );
        };
        if (my $exc = OpenXPKI::Exception->caught()) {
            # ignore missing configuration
            if (($exc->message() 
             eq "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_ELEMENT")
            && (($type eq 'validators') || ($type eq 'conditions'))) {
                $count = 0;
            }
            else
            {
                $exc->rethrow();
            }
        } 
        elsif ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_INIT_WF_FACTORY_ADD_CONFIG_EVAL_ERROR_DURING_CONFIGFILE_PARSING',
                params  => {
                    'ERROR' => $EVAL_ERROR,
                },
            );
        }
        if (! defined $count) {
            OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_GET_WORKFLOW_FACTORY_MISSING_WORKFLOW_CONFIGURATION",
            params => {
                configtype => $type,
            });
        }

        for (my $ii = 0; $ii < $count; $ii++) {
            my $entry = $xml_config->get_xpath (
                XPATH     => [ 'pki_realm', 'workflow_config', $type, 'configfile' ],
                COUNTER   => [ $idx       , 0,            0,     $ii ],
                CONFIG_ID => $xml_config_id,
            );
            # cf. above ...
            local *Workflow::State::FACTORY = sub { return $workflow_factory };
            ##! 4: "config file: $entry"
            $workflow_factory->add_config_from_file(
                $workflow_config{$type}->{factory_param}  => $entry,
            );
        }
    }
    ##! 64: 'config added completely'

    my $workflow_table = 'WORKFLOW';
    my $workflow_history_table = 'WORKFLOW_HISTORY';
    # persister configuration should not be user-configurable and is
    # static and identical throughout OpenXPKI
    $workflow_factory->add_config(
        persister => {
            name           => 'OpenXPKI',
            class          => 'OpenXPKI::Server::Workflow::Persister::DBI',
            workflow_table => $workflow_table,
            history_table  => $workflow_history_table,
        },
    );

    ##! 1: 'end'
    return 1;
}

sub __flatten_content {
    my $entry       = shift;
    my $force_array = shift;
    # as this method calls itself a large number of times recursively,
    # the debug levels are /a bit/ higher than usual ...
    ##! 256: 'entry: ' . Dumper $entry
    ##! 256: 'force_array: ' . Dumper $force_array;

    foreach my $key (keys %{$entry}) {
        if (ref $entry->{$key} eq 'ARRAY' &&
            scalar @{ $entry->{$key} } == 1 &&
            ref $entry->{$key}->[0] eq 'HASH' &&
            exists $entry->{$key}->[0]->{'content'} &&
            scalar keys %{ $entry->{$key}->[0] } == 1) {
            ##! 256: 'key: ' . $key . ', flattening (deleting array)'
            if (grep {$_ eq $key} @{ $force_array}) {
                ##! 256: 'force array'
                $entry->{$key} = [ $entry->{$key}->[0]->{'content'} ];
            }
            else {
                ##! 256: 'no force array - replacing array by scalar'
                $entry->{$key} = $entry->{$key}->[0]->{'content'};
            }
        }
        elsif (ref $entry->{$key} eq 'ARRAY') {
            ##! 256: 'entry is array but more than one element'
            for (my $i = 0; $i < scalar @{ $entry->{$key} }; $i++) {
                ##! 256: 'i: ' . $i
                if (ref $entry->{$key}->[$i] eq 'HASH') {
                    if (exists $entry->{$key}->[$i]->{'content'}) {
                        ##! 256: 'entry #' . $i . ' has content key, flattening'
                        $entry->{$key}->[$i] 
                            = $entry->{$key}->[$i]->{'content'};
                    }
                    else {
                        ##! 256: 'entry #' . $i . ' does not have content key'
                        ##! 512: ref $entry->{$key}->[$i]
                        if (ref $entry->{$key}->[$i] eq 'HASH') {
                            # no need to flatten scalars any more
                            ##! 256: 'recursively flattening more ...'
                            $entry->{$key}->[$i] = __flatten_content(
                                $entry->{$key}->[$i],
                                $force_array
                            );
                        }
                    }
                }
            }
        }
    }
    return $entry;
}

sub get_current_xml_config
{
    my $keys = { @_ };

    ##! 1: "start"

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_XML_CONFIG_MISSING_CONFIG");
    }
    if (not -e $keys->{"CONFIG"})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_XML_CONFIG_FILE_DOES_NOT_EXIST",
            params  => {"FILENAME" => $keys->{CONFIG}});
    }
    if (not -r $keys->{"CONFIG"})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_XML_CONFIG_FILE_NOT_READABLE",
            params  => {"FILENAME" => $keys->{CONFIG}});
    }

    return OpenXPKI::XML::Config->new (CONFIG => $keys->{"CONFIG"});
}

sub get_xml_config {
    my $keys = { @_ };

    ##! 1: "start"
    my @serializations = ();

    my $curr_config_ser = $current_xml_config->get_serialized();
    ##! 16: 'serialized current config: ' . $curr_config_ser
    my $curr_config_id = sha1_base64($curr_config_ser);
    ##! 16: 'curr config ID: ' . $curr_config_id
    log_wrapper(
	{
	    MESSAGE  => "Current configuration ID: " . $curr_config_id,
	    PRIORITY => "info",
	    FACILITY => "system",
	});
    
    # get all current configuration entries from the database
    CTX('dbi_backend')->connect();
    my $xml_config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => {VALUE => '%', OPERATOR => "LIKE"},
        },
    );
    CTX('dbi_backend')->disconnect();

    if (! defined $xml_config_entries
        || ref $xml_config_entries ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_GET_XML_CONFIG_CONFIG_DB_ERROR',
        );
    }

    ### migration from old serialization format to new one ...

   CONFIG:
    foreach my $xml_config (@{ $xml_config_entries }) {
        # the database entry _might_ still use the old Serialization::Simple
        # format, so we check for this and convert if necessary ...
        if ($xml_config->{DATA} =~ m{ \A HASH }xms) {
            my $old_identifier = $xml_config->{CONFIG_IDENTIFIER};
            my $ser_simple = OpenXPKI::Serialization::Simple->new();
            my $ser_fast   = OpenXPKI::Serialization::Fast->new();

            my $deserialized_config = $ser_simple->deserialize($xml_config->{DATA});
            ##! 128: 'deserialized config: ' . Dumper $deserialized_config

            my $xs = $current_xml_config->xml_simple();
            ##! 128: 'xs: ' . Dumper $xs

            if (Test::More::_deep_check($deserialized_config, $xs)) {
                ##! 16: 'current config found in db, deleting it'
                # this is the current config, just delete it, it will
                # be added again anyways ...
                CTX('dbi_backend')->connect();
                CTX('dbi_backend')->delete(
                    TABLE => 'CONFIG',
                    DATA  => {
                        'CONFIG_IDENTIFIER' => $old_identifier,
                    },
                );
                CTX('dbi_backend')->commit();
                CTX('dbi_backend')->disconnect();
                # update references in workflow_context
                CTX('dbi_workflow')->connect();
                CTX('dbi_workflow')->update(
                    TABLE => 'WORKFLOW_CONTEXT',
                    DATA  => {
                        'WORKFLOW_CONTEXT_VALUE' => $curr_config_id,
                    },
                    WHERE => {
                        'WORKFLOW_CONTEXT_KEY'   => 'config_id',
                        'WORKFLOW_CONTEXT_VALUE' => $old_identifier,
                    },
                );
                CTX('dbi_workflow')->commit();
                CTX('dbi_workflow')->disconnect();
                next CONFIG;
            }
            my $reserialized_config = $ser_fast->serialize($deserialized_config);
            my $new_identifier = sha1_base64($reserialized_config);
            ##! 16: 'old_identifier: ' . $old_identifier
            ##! 16: 'new_identifier: ' . $new_identifier

            # update config database
            CTX('dbi_backend')->connect();
            CTX('dbi_backend')->update(
                TABLE => 'CONFIG',
                DATA  => {
                    CONFIG_IDENTIFIER => $new_identifier,
                    DATA              => $reserialized_config,
                },
                WHERE => {
                    CONFIG_IDENTIFIER => $old_identifier,
                },
            );
            CTX('dbi_backend')->commit();
            CTX('dbi_backend')->disconnect();

            # update references in workflow_context
            CTX('dbi_workflow')->connect();
            CTX('dbi_workflow')->update(
                TABLE => 'WORKFLOW_CONTEXT',
                DATA  => {
                    'WORKFLOW_CONTEXT_VALUE' => $new_identifier,
                },
                WHERE => {
                    'WORKFLOW_CONTEXT_KEY'   => 'config_id',
                    'WORKFLOW_CONTEXT_VALUE' => $old_identifier,
                },
            );
            CTX('dbi_workflow')->commit();
            CTX('dbi_workflow')->disconnect();
        }
    }

    # check whether current config is already in database, if not, add it
    CTX('dbi_backend')->connect();
    my $curr_config_db = CTX('dbi_backend')->first(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => {VALUE => $curr_config_id},
        },
    );
    if (! defined $curr_config_db) {
        ##! 16: 'current configuration is not yet in database, adding it'
        # TODO - log?
        CTX('dbi_backend')->insert(
            TABLE => 'CONFIG',
            HASH  => {
                CONFIG_IDENTIFIER => $curr_config_id,
                DATA              => $curr_config_ser,
            },
        );
        CTX('dbi_backend')->commit();
    }
    CTX('dbi_backend')->disconnect();

    # get the new list of config entries
    CTX('dbi_backend')->connect();
    $xml_config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => {VALUE => '%', OPERATOR => "LIKE"},
        },
    );
    CTX('dbi_backend')->disconnect();

    if (! defined $xml_config_entries
        || ref $xml_config_entries ne 'ARRAY'
        || scalar @{ $xml_config_entries } == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_NO_CONFIG_ENTRIES_IN_DB',
        );
    }
    foreach my $xml_config (@{ $xml_config_entries }) {
        ##! 128: 'config->{DATA}: ' . $xml_config->{DATA}
        push @serializations, $xml_config->{DATA};
    }
    ##! 16: '# of serializations: ' . scalar @serializations

    return OpenXPKI::XML::Config->new(
        SERIALIZED_CACHES => \@serializations,
        DEFAULT           => $curr_config_id,
    );
}

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
        if ($xml_config->get_meta('system.database.logging')) {
            ##! 16: 'use logging section'            
            $dbpath = 'system.database.logging';
        }
        %params = (LOG => OpenXPKI::Server::Log::NOOP->new());
    }
    else {
        %params = (LOG => CTX('log'));
    }

    my $db_config = $xml_config->get_hash($dbpath);
    
    foreach my $key qw(server_id server_shift type name namespace host port user passwd) {
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

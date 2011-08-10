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
use OpenXPKI::Debug;
use OpenXPKI::i18n qw(set_language set_locale_prefix);
use OpenXPKI::Exception;

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

use OpenXPKI::Server::Context qw( CTX );
                
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
  pki_realm
  volatile_vault
  acl
  api
  pki_realm_by_cfg
  authentication
  notification
  server
);


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


sub __do_init_pki_realm {
    ##! 1: "init pki_realm"
    my $pki_realm    = get_pki_realms({
        CONFIG_ID => 'default',
    });
    
    OpenXPKI::Server::Context::setcontext(
	{
	    pki_realm => $pki_realm,
	});
}

sub __do_init_pki_realm_by_cfg {
    ##! 1: 'init pki_realm_by_cfg'
    CTX('dbi_backend')->connect();
    CTX('dbi_backend')->commit();
    my $config_ids = CTX('api')->list_config_ids();
    CTX('dbi_backend')->disconnect();
    if (! defined $config_ids || ref $config_ids ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_DO_INIT_PKI_REALM_BY_CFG_CONFIG_IDS_NOT_FOUND',
        );
    }
    my $pki_realm_by_cfg = {};
    foreach my $config_id (@{ $config_ids }) {
        ##! 4: 'config_id: ' . $config_id
	log_wrapper(
	    {
		MESSAGE  => 'Instantiating archived configuration ID: ' . $config_id,
		PRIORITY => 'info',
		FACILITY => 'system',
	    });
	eval {
	    $pki_realm_by_cfg->{$config_id} = get_pki_realms(
		{
		    CONFIG_ID => $config_id,
		});
	};
        if (my $exc = OpenXPKI::Exception->caught()) {
            # ignore errorneous configuration, but complain about it
	    log_wrapper(
		{
		    MESSAGE => 'Invalid configuration detected, ignoring configuriation ID ' . $config_id,
		    PRIORITY => 'warn',
		    FACILITY => 'system',
		});
        }
        elsif ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_INIT_PKI_REALMS_BY_CFG',
                params  => {
                    'ERROR' => $EVAL_ERROR,
                },
		);
        }
    }
    ##! 4: 'setting context'
    ##! 64: 'pki_realm_by_cfg: ' . Dumper $pki_realm_by_cfg
    OpenXPKI::Server::Context::setcontext({
        pki_realm_by_cfg => $pki_realm_by_cfg,
    });
}
    
sub __do_init_volatile_vault {
    ##! 1: "init volatile vault"

    my $realms = CTX('pki_realm');
    
    # get a default token
    # FIXME: We use the first PKI realm's default token. This is an 
    # arbitrary choice - we should consider to have a "global" default 
    # token that is not bound to a specific realm.

    my $firstrealm = (sort keys %{$realms})[0];
    if (! defined $firstrealm) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DO_INIT_VOLATILEVAULT_MISSING_PKI_REALM");
	
    }
    my $token =  $realms->{$firstrealm}->{crypto}->{default};

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
    my $config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => '%',
        },
    );
    CTX('dbi_backend')->disconnect();

    if (! defined $config_entries
        || ref $config_entries ne 'ARRAY'
        || scalar @{ $config_entries } == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_GET_WORKFLOW_FACTORY_NO_CONFIG_IDENTIFIERS_IN_DB',
        );
    }

    my $workflow_factories = {};
    foreach my $config (@{ $config_entries }) {
        my $id = $config->{CONFIG_IDENTIFIER};
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
    my $config_id        = $arg_ref->{CONFIG_ID};
    ##! 4: 'config_id: ' . $config_id
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
                CONFIG_ID => $config_id,
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
                            CONFIG_ID => $config_id,
                        );
                    };
                    ##! 16: 'secondlevel_count: ' . $secondlevel_count
                    for (my $iii = 0; $iii < $secondlevel_count; $iii++) {
                        my $entry = $xml_config->get_xpath_hashref(
                            XPATH     => [ @base_path, $iterator ],
                            COUNTER   => [ @base_ctr , $iii      ],
                            CONFIG_ID => $config_id,
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
                        CONFIG_ID => $config_id,
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
                CONFIG_ID => $config_id,
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
                CONFIG_ID => $config_id,
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
    my $config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => '%',
        },
    );
    CTX('dbi_backend')->disconnect();

    if (! defined $config_entries
        || ref $config_entries ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_GET_XML_CONFIG_CONFIG_DB_ERROR',
        );
    }

    ### migration from old serialization format to new one ...

   CONFIG:
    foreach my $config (@{ $config_entries }) {
        # the database entry _might_ still use the old Serialization::Simple
        # format, so we check for this and convert if necessary ...
        if ($config->{DATA} =~ m{ \A HASH }xms) {
            my $old_identifier = $config->{CONFIG_IDENTIFIER};
            my $ser_simple = OpenXPKI::Serialization::Simple->new();
            my $ser_fast   = OpenXPKI::Serialization::Fast->new();

            my $deserialized_config = $ser_simple->deserialize($config->{DATA});
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
            CONFIG_IDENTIFIER => $curr_config_id,
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
    $config_entries = CTX('dbi_backend')->select(
        TABLE   => 'CONFIG',
        DYNAMIC => {
            CONFIG_IDENTIFIER => '%',
        },
    );
    CTX('dbi_backend')->disconnect();

    if (! defined $config_entries
        || ref $config_entries ne 'ARRAY'
        || scalar @{ $config_entries } == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_INIT_NO_CONFIG_ENTRIES_IN_DB',
        );
    }
    foreach my $config (@{ $config_entries }) {
        ##! 128: 'config->{DATA}: ' . $config->{DATA}
        push @serializations, $config->{DATA};
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

    if (not $keys->{CONFIG})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_I18N_MISSING_CONFIG");
    }

    set_locale_prefix ($keys->{CONFIG}->get_xpath (XPATH => "common/i18n/locale_directory", CONFIG_ID => 'default'));
    set_language      ($keys->{CONFIG}->get_xpath (XPATH => "common/i18n/default_language", CONFIG_ID => 'default'));

    binmode STDOUT, ":utf8";
    binmode STDIN,  ":utf8";

    return 1;
}


sub get_crypto_layer
{
    ##! 1: "start"

    return OpenXPKI::Crypto::TokenManager->new();
}



sub get_pki_realms
{
    my $arg_ref = shift;
    ##! 1: "start"
    my $cfg_id = $arg_ref->{CONFIG_ID};
    ##! 16: 'cfg_id: ' . $cfg_id

    my $config = CTX('xml_config');
    my $crypto = CTX('crypto_layer');

    ##! 16: 'crypto + config'
    
    ### get all PKI realms
    my %realms = ();
    my $count = $config->get_xpath_count(
        XPATH     => "pki_realm",
        CONFIG_ID => $cfg_id,
    );
    ##! 16: 'number of PKI realms: ' . $count
    for (my $i = 0 ; $i < $count ; $i++)
    {
        ## prepare crypto stuff for every PKI realm

        my $name = $config->get_xpath (
            XPATH    => [ 'pki_realm', 'name' ],
            COUNTER  => [ $i, 0 ],
            CONFIG_ID => $cfg_id,
        );

        my $defaulttoken = __get_default_crypto_token (
            PKI_REALM => $name,
            CONFIG_ID => $cfg_id,
        );

        $realms{$name}->{crypto}->{default} = $defaulttoken;
        log_wrapper(
            {
            MESSAGE  => "Attached default token for PKI realm '$name'",
            PRIORITY => "info",
            FACILITY => "system",
        });
	
        my @xpath   = ( 'pki_realm', 'common', 'profiles' );
        my @counter = ( $i,         0,        0 );
        
        foreach my $entrytype (qw( endentity crl )) {
            ### entrytype: $entrytype

            my $nr_of_entries = $config->get_xpath_count(
                XPATH     => [ @xpath,   $entrytype, 'profile' ],
                COUNTER   => [ @counter, 0 ],
                CONFIG_ID => $cfg_id,
            );
	    
            ### entries: $nr_of_entries
            foreach (my $jj = 0; $jj < $nr_of_entries; $jj++) {
                my $entryid = $config->get_xpath(
                    XPATH   => [ @xpath,   $entrytype, 'profile', 'id' ],
                    COUNTER => [ @counter, 0,          $jj,       0 ],
                    CONFIG_ID => $cfg_id,
                );

                VALIDITYTYPE:
                foreach my $validitytype (qw( notbefore notafter )) {
                    next VALIDITYTYPE if (($entrytype eq "crl") &&
                        ($validitytype eq "notbefore"));

                    ### validitytype: $validitytype

                    my $validity;
                    my $format;
                    # parse validity entry
                    eval {
                        $format = $config->get_xpath(
                            XPATH     => [ @xpath,   $entrytype, 'profile', 'validity', $validitytype, 'format' ],
                            COUNTER   => [ @counter, 0,          $jj,       0,          0,             0 ],
                            CONFIG_ID => $cfg_id,
                        );

                        $validity = $config->get_xpath(
                            XPATH   => [ @xpath,   $entrytype, 'profile', 'validity', $validitytype ],
                            COUNTER => [ @counter, 0,          $jj,        0,         0 ],
                            CONFIG_ID => $cfg_id,
                        );

                    };
                    if (my $exc = OpenXPKI::Exception->caught()) {
                        # ignore exception for missing 'notbefore' entry
                        if (($exc->message() 
                                eq "I18N_OPENXPKI_XML_CACHE_GET_XPATH_MISSING_ELEMENT")
                            && ($validitytype eq "notbefore")) {
                            # default: "now"
                            $validity = undef;
                        }
                        else
                        {
                            $exc->rethrow();
                        }
                    } elsif ($EVAL_ERROR) {
                        OpenXPKI::Exception->throw (
                            message => "I18N_OPENXPKI_SERVER_INIT_GET_PKI_REALMS_VALIDITY_ERROR",
                            params  => {
                                EVAL_ERROR => $EVAL_ERROR,
                            });
                    }

                    ### got format: $format
                    ### got validity: $validity

                    if (defined $validity) {
                        $realms{$name}->{$entrytype}->{id}->{$entryid}->{validity}->{$validitytype} = 
                        {
                            'format' => $format,
                            'validity' => $validity,
                        };

                        log_wrapper(
                            {
                                MESSAGE  => "Accepted '$entryid' $entrytype $validitytype validity ($format: $validity) for PKI realm '$name'",
                                PRIORITY => "info",
                                FACILITY => "system",
                            });

                    }
                }
            }
        }
        #############################################################
        ##! 129: '--------------------------------- get ldap options'  
	#
        my @ldap_path   = ('pki_realm', 'common/ldap_options');
        my @ldap_counter= (         $i,             0);
        eval {
         $realms{$name}->{ldap_enable} = $config->get_xpath(
	        XPATH   => [  @ldap_path   ,'ldap_enable' ],
  	        COUNTER => [  @ldap_counter,           0  ],
              CONFIG_ID => $cfg_id,
	 );
	};
        if ($EVAL_ERROR) {
         log_wrapper({
    	  MESSAGE  => "No LDAP options found, LDAP turned off",
    	  PRIORITY => "warn",
    	  FACILITY => "system",
	 });
	 $realms{$name}->{ldap_enable} = "no";
	}
	if($realms{$name}->{ldap_enable} eq "yes"){
        ##! 129: 'LDAP LOADED, STATUS '.$realms{$name}->{ldap_enable}
	  $realms{$name}->{ldap_excluded_roles} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_excluded_roles' ],
                COUNTER => [  @ldap_counter,                    0 ],
	      CONFIG_ID => $cfg_id,
	  );
          $realms{$name}->{ldap_suffix}=[];
          my $suffix_count = $config->get_xpath_count(
                XPATH   => [  @ldap_path    ,
	                     'ldap_suffixes','ldap_suffix' ],
                COUNTER => [  @ldap_counter,           0   ],
	      CONFIG_ID => $cfg_id,
	  );
          for (my $suffix_counter=0; 
	          $suffix_counter < $suffix_count;
	          $suffix_counter++){
	       my $ldap_suffix =
                  $config->get_xpath(
                        XPATH   => [  @ldap_path    ,
	                             'ldap_suffixes','ldap_suffix' ],
                        COUNTER => [  @ldap_counter, 
		                                  0,$suffix_counter],
		      CONFIG_ID => $cfg_id,
	       );
	       push @{$realms{$name}->{ldap_suffix}}, $ldap_suffix;
          };
	  $realms{$name}->{ldap_server} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_server' ],
                COUNTER => [  @ldap_counter,           0  ],
	      CONFIG_ID => $cfg_id,
	  );
	  $realms{$name}->{ldap_port} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_port' ],
                COUNTER => [  @ldap_counter,         0  ],
	      CONFIG_ID => $cfg_id,
	  );
	  $realms{$name}->{ldap_version} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_version' ],
                COUNTER => [  @ldap_counter,            0  ],
	      CONFIG_ID => $cfg_id,
	  );
	  #--- TLS block
          $realms{$name}->{ldap_tls} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_tls','use_tls' ],
                COUNTER => [  @ldap_counter,         0,       0  ],
	      CONFIG_ID => $cfg_id,
	  );
          if($realms{$name}->{ldap_tls} eq "yes"){
             $realms{$name}->{ldap_client_cert} = 
	         $config->get_xpath(
                     XPATH   => [  @ldap_path   ,'ldap_tls',
     	                         'client_cert'],
                     COUNTER => [  @ldap_counter,         0,0],
	           CONFIG_ID => $cfg_id,
	         );

             $realms{$name}->{ldap_client_key} = 
		 $config->get_xpath(
                     XPATH   => [  @ldap_path   ,'ldap_tls',
     	                          'client_key'],
                     COUNTER => [  @ldap_counter,         0,0],
	           CONFIG_ID => $cfg_id,
	         );

             $realms{$name}->{ldap_ca_cert} = 
	         $config->get_xpath(
	             XPATH   => [  @ldap_path   ,'ldap_tls',
	                             'ca_cert'],
                     COUNTER => [  @ldap_counter,         0,0],
	           CONFIG_ID => $cfg_id,
	         );
          };
	  #--- end of TLS block    
	  
	  #--- SASL block
	  $realms{$name}->{ldap_sasl} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_sasl','use_sasl'],
                COUNTER => [  @ldap_counter,          0,        0 ],
	      CONFIG_ID => $cfg_id,
	  );
          if($realms{$name}->{ldap_sasl} eq "yes"){
             $realms{$name}->{ldap_sasl_mech} = 
	         $config->get_xpath(
                     XPATH   => [ @ldap_path   ,'ldap_sasl',
		                  'sasl_mech'                ],
                     COUNTER => [ @ldap_counter,          0,0],
	           CONFIG_ID => $cfg_id,
	         );
          };
	  #--- end of SASL block
	  
	  $realms{$name}->{ldap_login} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_login'],
                COUNTER => [  @ldap_counter,           0],
	      CONFIG_ID => $cfg_id,
	  );

          $realms{$name}->{ldap_password} = $config->get_xpath(
                XPATH   => [  @ldap_path   ,'ldap_password'],
                COUNTER => [  @ldap_counter,           0   ],
	      CONFIG_ID => $cfg_id,
	  );

          ##! 129: 'ldap: loading schema'
          my @schema_prefix    = ('pki_realm','common/ldap_options/schema');
          my @schema_counter   = ( $i        , 0                          );
          my @cert_types = ("default", "certificate", "ca");
	  my $rdn;
          my $rdn_count;
	  my $attribute_count;
          my $attr_type;
	  my $must_count;
	  my $may_count;
	  my $structural_count;
	  my $auxiliary_count;

          ##! 129: 'block: default, certificate, ca'
          foreach my $cert_type (@cert_types) { 
           ##! 129: 'load_schema: LOADING '.$cert_type.' BLOCK'
           $rdn_count = $config->get_xpath_count(
                XPATH   => [ @schema_prefix,$cert_type,'rdn' ],
                COUNTER => [ @schema_counter, 0 ],
	      CONFIG_ID => $cfg_id,
	   );

           ##! 129: 'load_schema: '.$cert_type.' rdns:'. $rdn_count
           next if (not $rdn_count);
	   ##! 129: 'block: rdns'
           for ($rdn=0; $rdn < $rdn_count; $rdn++){
            ##! 129: 'attributetype'
            $attr_type = $config->get_xpath (
              XPATH    => [ @schema_prefix, $cert_type,'rdn',
	                    'attributetype'],
              COUNTER  => [ @schema_counter,0,          $rdn, 0 ],
	     CONFIG_ID => $cfg_id,
	    );

            $realms{$name}->{schema}->{$cert_type}->{lc ($attr_type)}->{attributetype} =
             $attr_type;
            $attr_type = lc ($attr_type);
            ##! 129: 'load_schema: loading attributetype '.$attr_type 
            $must_count = $config->get_xpath_count (
               XPATH    => [ @schema_prefix, $cert_type,'rdn',
	                   "must/attributetype" ],
               COUNTER  => [ @schema_counter,0,          $rdn ],
	      CONFIG_ID => $cfg_id,
	    );

            ##! 129: 'load_schema: must: count: '.$must_count
            $must_count = 0 if (not $must_count);

            ##! 129: 'block: must'
            for (my $attribute_count=0; 
	            $attribute_count < $must_count;
	            $attribute_count++){ 
             $realms{$name}->{schema}->{$cert_type}->{$attr_type}->{must}->[$attribute_count] =
              $config->get_xpath (
                XPATH    => [ @schema_prefix, $cert_type,'rdn',
	                     "must/attributetype" ],
                COUNTER  => [ @schema_counter,0,          $rdn,
	                         $attribute_count ],
	       CONFIG_ID => $cfg_id,
	      );
             ##! 129: 'load_schema: must'
            }
	    ##! 129: 'end of block: must'
            eval {
             $may_count = $config->get_xpath_count (
               XPATH    => [ @schema_prefix, $cert_type,'rdn',
	                     "may/attributetype" ],
               COUNTER  => [ @schema_counter,0        ,$rdn ],
	      CONFIG_ID => $cfg_id,
	     );
            };
	    if ($EVAL_ERROR) {
             ##! 129: 'load_schema: may: count: ZERO'
             $may_count = 0;
            }
            else {
             ##! 129: 'block: may'
             ##! 129: 'load_schema: may: count: '.$may_count 
	     for ($attribute_count=0; 
	          $attribute_count < $may_count; 
	          $attribute_count++){ 
              $realms{$name}->{schema}->{$cert_type}->{$attr_type}->{may}->[$attribute_count] =
               $config->get_xpath (
                 XPATH    => [ @schema_prefix, $cert_type,'rdn',
	                       "may/attributetype" ],
                 COUNTER  => [ @schema_counter,0,          $rdn,
	                          $attribute_count ],
	        CONFIG_ID => $cfg_id,
	       );

            ##! 129: 'load_schema: may'
             }
            };
	    ##  129: 'end of block: may'
            $structural_count = $config->get_xpath_count (
              XPATH    => [ @schema_prefix, $cert_type,'rdn',
                           "structural/objectclass" ],
              COUNTER  => [ @schema_counter,0        ,$rdn ],
	     CONFIG_ID => $cfg_id,
	    );

            ##! 129: 'load_schema: count: '.$count
            $structural_count = 0 if (not $structural_count);
            ## 129: 'block: structural'
            for ($attribute_count=0; 
 	         $attribute_count < $structural_count; 
 		 $attribute_count++){
             $realms{$name}->{schema}->{$cert_type}->{$attr_type}->{structural}->[$attribute_count] =
              $config->get_xpath (
                XPATH    => [ @schema_prefix, $cert_type,'rdn',
	                     "structural/objectclass" ],
                COUNTER  => [ @schema_counter,0,          $rdn,
	                            $attribute_count ],
	       CONFIG_ID => $cfg_id,
	      );

            ##! 129: 'load_schema: structural'
            } 
            ##! 129: 'end of block: structural'
            eval {
             $auxiliary_count = $config->get_xpath_count (
               XPATH    => [ @schema_prefix, $cert_type,'rdn',
   	                     "auxiliary/objectclass" ],
               COUNTER  => [ @schema_counter,0          ,$rdn ],
	      CONFIG_ID => $cfg_id,
	     );
            };
	    if ($EVAL_ERROR) {
             ##! 129 : 'load_schema: auxiliary: count: ZERO'
             $auxiliary_count = 0;
            }
            else {
             ##! 129 : 'load_schema: auxiliary: count: '.$count
             ##! 129 : 'block: auxiliary'
             for ($attribute_count=0; 
	          $attribute_count < $auxiliary_count; 
 	          $attribute_count++){
              $realms{$name}->{schema}->{$cert_type}->{$attr_type}->{auxiliary}->[$attribute_count] =
               $config->get_xpath (
                 XPATH    => [ @schema_prefix, $cert_type,'rdn',
	                    "auxiliary/objectclass" ],
                 COUNTER  => [ @schema_counter,0,          $rdn,
	                           $attribute_count ],
	        CONFIG_ID => $cfg_id,
	       );
              ##! 129: 'load_schema: auxiliary'
             };
            }; 
	    ##! 129: 'end of block: auxiliary'
           }; 
	   ##! 129: 'end of block: rdns'
          }; 
	  ##! 129: 'end of block: default, certificate, ca'
        }; 
	##! 129: 'end of block: ldap_enable=yes'
        ##! 129: '-------------------------------------The End of ldap section'
        ################################################################


        ### %realms

        # get all CA certificates for PKI realm
        # $realms{$name}->{ca}->{$ca}->{certificate} =
        # get end entity validities
        my $nr_of_ca_entries = 0;

        eval {
            # it might actually make sense not to have any CAs defined
            # in a given PKI realm, so don't die if get_xpath_count
            # fails ...
            $nr_of_ca_entries = $config->get_xpath_count(
                    XPATH   => ['pki_realm', 'ca'],
                    COUNTER => [$i],
                    CONFIG_ID => $cfg_id,
            );
        };

        my $issuing_ca_count = 0;
        my $scep_count = 0;
        my $password_safe_count = 0;

        ISSUINGCA:
        for (my $jj = 0; $jj < $nr_of_ca_entries; $jj++) {
            my $ca_id = $config->get_xpath(
                XPATH =>   ['pki_realm', 'ca', 'id'],
                COUNTER => [$i,          $jj,  0 ],
                CONFIG_ID => $cfg_id,
            );


            # sanity check: there must be a CRL validity configuration
            # for this issuing CA
            if (! exists $realms{$name}->{crl}->{id}->{$ca_id}->{validity}) {
                OpenXPKI::Exception->throw (
                    message => "I18N_OPENXPKI_SERVER_INIT_PKI_REALMS_NO_CRL_VALIDITY",
                    params => {
                        CAID   => $ca_id,
                    },
                );
            }


            # record this issuing CA as potentially present in the 
            # PKI Realm configuration
            $realms{$name}->{ca}->{id}->{$ca_id}->{status} = 0;

            # cert identifier
            eval {
                my $cert_identifier = __get_cert_identifier({
                    TYPE          => 'ca',
                    REALM_COUNTER => $i,
                    TYPE_COUNTER  => $jj,
                    CONFIG_ID     => $cfg_id,
                });
                ##! 16: 'identifier: ' . $cert_identifier
                $realms{$name}->{ca}->{id}->{$ca_id}->{identifier} = $cert_identifier;
            };
            if ($EVAL_ERROR) {
                log_wrapper({
                        MESSAGE  => "Could not determine CA identifier for CA '$ca_id' (PKI realm $name)",
                        PRIORITY => "warn",
                        FACILITY => "system",
                    });

                log_wrapper({
                        MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
                        PRIORITY => "warn",
                        FACILITY => "monitor",
                    });

                next ISSUINGCA;
            }

            ###########################################################
            # get certificate from DB and save it in the pki_realms CTX

            my $certificate = __get_certificate({
                IDENTIFIER => $realms{$name}->{ca}->{id}->{$ca_id}->{identifier},
            });

            ##! 16: 'certificate: ' . $certificate
            if (! defined $certificate) {
                log_wrapper({
                        MESSAGE  => "Could not read issuing CA certificate from database for CA '$ca_id' (PKI realm $name)",
                        PRIORITY => "warn",
                        FACILITY => "system",
                    });

                log_wrapper({
                        MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
                        PRIORITY => "warn",
                        FACILITY => "monitor",
                    });

                next ISSUINGCA;
            }
            my $cacert
            = OpenXPKI::Crypto::X509->new(TOKEN => $defaulttoken,
                DATA  => $certificate);

            if (! defined $cacert) {
                log_wrapper({
                        MESSAGE  => "Could not parse issuing CA certificate from database for CA '$ca_id' (PKI realm $name)",
                        PRIORITY => "warn",
                        FACILITY => "system",
                    });

                log_wrapper({
                        MESSAGE  => "Issuing CA '$ca_id' (PKI realm $name) is unavailable",
                        PRIORITY => "warn",
                        FACILITY => "monitor",
                    });

                next ISSUINGCA;
            }

            ##! 16: 'certificate: ' . $certificate
            my $token = $crypto->get_token(
                TYPE        => "CA",
                ID          => $ca_id,
                PKI_REALM   => $name,
                CERTIFICATE => $certificate,
                CONFIG_ID   => $cfg_id,
            );

            $realms{$name}->{ca}->{id}->{$ca_id}->{certificate}
            = $certificate;
            $realms{$name}->{ca}->{id}->{$ca_id}->{crypto} = $token;
            $realms{$name}->{ca}->{id}->{$ca_id}->{cacert} = $cacert;
            $realms{$name}->{ca}->{id}->{$ca_id}->{status} = 1;
            $realms{$name}->{ca}->{id}->{$ca_id}->{notbefore} 
            = $cacert->get_parsed("BODY", "NOTBEFORE");
            $realms{$name}->{ca}->{id}->{$ca_id}->{notafter} 
            = $cacert->get_parsed("BODY", "NOTAFTER");

            $issuing_ca_count++;

            log_wrapper({
                    MESSAGE  => "Attached CA token for issuing CA '$ca_id' of PKI realm '$name'",
                    PRIORITY => "info",
                    FACILITY => "system",
                });

            log_wrapper({
                    MESSAGE  => "Issuing CA $ca_id of PKI realm '$name' validity is " 
                    . OpenXPKI::DateTime::convert_date(
                        {
                            DATE => $realms{$name}->{ca}->{id}->{$ca_id}->{notbefore},
                            OUTFORMAT => 'printable',
                        }) 
                    . ' - '
                    . OpenXPKI::DateTime::convert_date(
                        {
                            DATE => $realms{$name}->{ca}->{id}->{$ca_id}->{notafter},
                            OUTFORMAT => 'printable',
                        }
                    ),
                    PRIORITY => "info",
                    FACILITY => "system",
                });

            ###############################################
            # crl_publication info

            my @base_path = ('pki_realm', 'ca', 'crl_publication');
            my @base_ctr  = ($i,          $jj,   0);
            eval {
                my $crl_publication_id = $config->get_xpath(
                    XPATH   => [ @base_path ],
                    COUNTER => [ @base_ctr  ],
                    CONFIG_ID => $cfg_id,
                );
                $realms{$name}->{ca}->{id}->{$ca_id}->{crl_publication} = 1; # only executed if get_xpath does not crash
            };
            eval {
                my $number_of_files = $config->get_xpath_count(
                    XPATH   => [ @base_path, 'file'],
                    COUNTER => [ @base_ctr ],
                    CONFIG_ID => $cfg_id,
                );
                my @files;
                ##! 16: 'nr_of_files: ' . $number_of_files
                for (my $kkk = 0; $kkk < $number_of_files; $kkk++) {
                    my $filename = $config->get_xpath(
                        XPATH   => [ @base_path, 'file', 'filename' ],
                        COUNTER => [ @base_ctr, $kkk   , 0          ],
                        CONFIG_ID => $cfg_id,
                    );
                    ##! 16: 'filename: ' . $filename
                    my $format = $config->get_xpath(
                        XPATH   => [ @base_path, 'file', 'format'   ],
                        COUNTER => [ @base_ctr, $kkk   , 0          ],
                        CONFIG_ID => $cfg_id,
                    );
                    ##! 16: 'format: ' . $format
                    push @files, {
                        'FILENAME' => $filename,
                        'FORMAT'   => $format,
                    };
                }
                ##! 16: '@files: ' . Dumper(\@files)
                $realms{$name}->{ca}->{id}->{$ca_id}->{crl_files} = \@files;
            };
        }

        # get all SCEP identifier for the PKI realm
        # $realms{$name}->{scep}->{$scep_id}->{identifier}
        my $nr_of_scep_entries = 0;
        eval { # this might fail because no scep server is defined
            # at all
            $nr_of_scep_entries = $config->get_xpath_count(
                XPATH   => ['pki_realm', 'scep'],
                COUNTER => [$i],
                CONFIG_ID => $cfg_id,
            );
        };

        SCEP_SERVER:
        for (my $jj = 0; $jj < $nr_of_scep_entries; $jj++) {
            my $scep_id = $config->get_xpath(
                XPATH =>   ['pki_realm', 'scep', 'id'],
                COUNTER => [$i,          $jj,  0 ],
                CONFIG_ID => $cfg_id,
            );

            # cert identifier
            eval {
                my $cert_identifier = __get_cert_identifier({
                    TYPE          => 'scep',
                    REALM_COUNTER => $i,
                    TYPE_COUNTER  => $jj,
                    CONFIG_ID     => $cfg_id,
                });
                ##! 16: 'identifier: ' . $cert_identifier
                $realms{$name}->{scep}->{id}->{$scep_id}->{identifier} = $cert_identifier;
            };
            if ($EVAL_ERROR) {
                log_wrapper({
                        MESSAGE  => "Could not determine identifier for SCEP server '$scep_id' (PKI realm $name)",
                        PRIORITY => "warn",
                        FACILITY => "system",
                    });

                log_wrapper({
                        MESSAGE  => "SCEP server '$scep_id' (PKI realm $name) is unavailable",
                        PRIORITY => "warn",
                        FACILITY => "monitor",
                    });

                next SCEP_SERVER;
            }
            my $certificate = __get_certificate({
                IDENTIFIER => $realms{$name}->{scep}->{id}->{$scep_id}->{identifier},
            });
            my $token = $crypto->get_token(
                TYPE        => "SCEP",
                ID          => $scep_id,
                PKI_REALM   => $name,
                CERTIFICATE => $certificate,
                CONFIG_ID   => $cfg_id,
            );
            $realms{$name}->{scep}->{id}->{$scep_id}->{crypto} = $token;
            log_wrapper({
                    MESSAGE  => "Attached SCEP token for SCEP server '$scep_id' of PKI realm '$name'",
                    PRIORITY => "info",
                    FACILITY => "system",
                });

            # the retry time parameter is optional, so we put it in an eval block
            eval {
                $realms{$name}->{scep}->{id}->{$scep_id}->{'retry_time'}
                    = $config->get_xpath(
                        XPATH =>   ['pki_realm', 'scep', 'retry_time'],
                        COUNTER => [$i,          $jj,     0 ],
                        CONFIG_ID => $cfg_id,
                    );

            };

            # the scep_client section is optional, so put it in an eval block as well
            eval {
                $realms{$name}->{scep}->{id}->{$scep_id}->{'scep_client'}->{'enrollment_role'} =
                    $config->get_xpath(
                        XPATH     => ['pki_realm', 'scep', 'scep_client', 'enrollment_role'],
                        COUNTER   => [$i,          $jj,     0,             0 ],
                        CONFIG_ID => $cfg_id,
                    );
            };

            eval {
                $realms{$name}->{scep}->{id}->{$scep_id}->{'scep_client'}->{'autoissuance_role'} =
                    $config->get_xpath(
                        XPATH     => ['pki_realm', 'scep', 'scep_client', 'autoissuance_role'],
                        COUNTER   => [$i,          $jj,     0,             0 ],
                        CONFIG_ID => $cfg_id,
                    );
            };
            $scep_count++;
        }

        # get all PASSWORD_SAFE identifiers for the PKI realm
        my $nr_of_password_safe_entries = 0;
        eval { # this might fail because no password safe is defined
               # at all
            $nr_of_password_safe_entries = $config->get_xpath_count(
                XPATH   => ['pki_realm', 'password_safe'],
                COUNTER => [$i],
                CONFIG_ID => $cfg_id,
            );
        };
        ##! 16: 'password safe entries: ' . $nr_of_password_safe_entries

        PASSWORD_SAFE:
        for (my $jj = 0; $jj < $nr_of_password_safe_entries; $jj++) {
            my $password_safe_id = $config->get_xpath(
                XPATH =>   ['pki_realm', 'password_safe', 'id'],
                COUNTER => [$i,          $jj,  0 ],
                CONFIG_ID => $cfg_id,
            );

            # cert identifier
            eval {
                my $cert_identifier = __get_cert_identifier({
                    TYPE          => 'password_safe',
                    REALM_COUNTER => $i,
                    TYPE_COUNTER  => $jj,
                    CONFIG_ID     => $cfg_id,
                });
                ##! 16: 'identifier: ' . $cert_identifier
                $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{identifier} = $cert_identifier;
            };
            if ($EVAL_ERROR) {
                ##! 16: 'EVAL_ERROR: ' . $EVAL_ERROR
                log_wrapper({
                        MESSAGE  => "Could not determine identifier for password safe '$password_safe_id' (PKI realm $name)",
                        PRIORITY => "warn",
                        FACILITY => "system",
                    });

                log_wrapper({
                        MESSAGE  => "Password safe '$password_safe_id' (PKI realm $name) is unavailable",
                        PRIORITY => "warn",
                        FACILITY => "monitor",
                    });

                next PASSWORD_SAFE;
            }
            my $certificate = __get_certificate({
                IDENTIFIER => $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{identifier},
            });
            my $cert_obj = OpenXPKI::Crypto::X509->new(
                TOKEN => $defaulttoken,
                DATA  => $certificate,
            );
            my $token = $crypto->get_token(
                TYPE        => "PASSWORD_SAFE",
                ID          => $password_safe_id,
                PKI_REALM   => $name,
                CERTIFICATE => $certificate,
                CONFIG_ID   => $cfg_id,
            );
            $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{certificate} = $certificate;
            $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{crypto} = $token;
            $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{notbefore} = $cert_obj->get_parsed('BODY', 'NOTBEFORE');
            $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{notafter} = $cert_obj->get_parsed('BODY', 'NOTAFTER');
            ##! 16: 'notbefore: ' . $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{notbefore}
            ##! 16: 'notafter: ' . $realms{$name}->{password_safe}->{id}->{$password_safe_id}->{notafter}

            log_wrapper({
                    MESSAGE  => "Attached password safe token for '$password_safe_id' of PKI realm '$name'",
                    PRIORITY => "info",
                    FACILITY => "system",
                });

            $password_safe_count++;
        }

        log_wrapper(
            {
                MESSAGE  => "Identified $issuing_ca_count issuing CAs for PKI realm '$name'",
                PRIORITY => "info",
                FACILITY => "system",
            });

        log_wrapper(
            {
                MESSAGE  => "Identified $scep_count SCEP servers for PKI realm '$name'",
                PRIORITY => "info",
                FACILITY => "system",
            });

        log_wrapper(
            {
                MESSAGE  => "Identified $password_safe_count password safes for PKI realm '$name'",
                PRIORITY => "info",
                FACILITY => "system",
            });
    }

    ### realms: %realms
    return \%realms;
}

sub __get_certificate {
    ##! 1: 'start'
    my $arg_ref    = shift;
    my $identifier = $arg_ref->{IDENTIFIER};
    ##! 16: 'identifier: ' . $identifier

    my $dbi = CTX('dbi_backend');
    $dbi->connect();
    my $certificate_db_entry = $dbi->first(
        TABLE   => 'CERTIFICATE',
        DYNAMIC => {
            IDENTIFIER => $identifier,
        },
    );
    $dbi->disconnect();
    my $certificate = $certificate_db_entry->{DATA}; # in PEM

    return $certificate;
}

sub __get_cert_identifier {
    ##! 1: 'start'
    my $arg_ref = shift;
    my $type    = $arg_ref->{TYPE};
    ##! 16: 'type: ' . $type
    my $i       = $arg_ref->{REALM_COUNTER};
    ##! 16: 'i: ' . $i
    my $jj      = $arg_ref->{TYPE_COUNTER};
    ##! 16: 'jj: ' . $jj
    my $cfg_id  = $arg_ref->{CONFIG_ID};
    ##! 16: 'cfg_id: ' . $cfg_id
    my $config  = CTX('xml_config');

    my $cert_identifier;
    eval {
        ##! 128: 'eval'
        $cert_identifier = $config->get_xpath(
            XPATH   => [ 'pki_realm', $type, 'cert', 'identifier' ],
            COUNTER => [ $i,           $jj, 0     , 0            ],
            CONFIG_ID => $cfg_id,
        );
    };
    if (! defined $cert_identifier) {
        # fallback, check if alias and realm are defined and retrieve
        # corresponding identifier from alias DB
        ##! 128: 'undefined'
        my $cert_alias = $config->get_xpath(
            XPATH   => [ 'pki_realm', $type, 'cert', 'alias' ],
            COUNTER => [ $i,          $jj,  0     , 0       ],
            CONFIG_ID => $cfg_id,
        );
        my $cert_realm = $config->get_xpath(
            XPATH   => [ 'pki_realm', $type, 'cert', 'realm' ],
            COUNTER => [ $i,          $jj,  0     , 0       ],
            CONFIG_ID => $cfg_id,
        );
        ##! 128: 'cert_alias: ' . $cert_alias
        ##! 128: 'cert_realm: ' . $cert_realm
        my $dbi = CTX('dbi_backend');
        $dbi->connect();
        my $cert = $dbi->first(
            TABLE   => 'ALIASES',
            DYNAMIC => {
                ALIAS     => $cert_alias,
                PKI_REALM => $cert_realm,
            },
        );
        $dbi->disconnect();
        ##! 128: 'cert: ' . Dumper($cert)
        if (defined $cert) {
            $cert_identifier = $cert->{IDENTIFIER};
        }
        else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_INIT_NO_IDENTIFIER_FOUND_IN_ALIASES_DB',
                params  => {
                    'ALIAS'     => $cert_alias,
                    'PKI_REALM' => $cert_realm,
                },
		log => {
		    logger => CTX('log'),
		    message => "Alias '$cert_alias' not found in PKI Realm '$cert_realm'",
		    facility => 'system',
		    priority => 'warn',
		}
            );
        }
    }
    return $cert_identifier;
}

sub __get_default_crypto_token
{
    my $keys = { @_ };
    ##! 1: "start"

    my $crypto = CTX('crypto_layer');

    if (not $keys->{PKI_REALM})
    {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_INIT_DEFAULT_CRYPTO_TOKEN_MISSING_PKI_REALM");
    }

    return $crypto->get_token (
        TYPE      => "DEFAULT",
		ID        => "default",
		PKI_REALM => $keys->{PKI_REALM},
        CONFIG_ID => $keys->{CONFIG_ID},
    );
}

sub get_dbi
{
    my $args = shift;

    ##! 1: "start"

    my $config = $current_xml_config;

    my %params;

    my $dbpath = 'database';
    if (exists $args->{PURPOSE} && $args->{PURPOSE} eq 'log') {
        ##! 16: 'purpose: log'
        $dbpath = 'log_database';
        %params = (LOG => OpenXPKI::Server::Log::NOOP->new());
    }
    else {
        %params = (LOG => CTX('log'));
    }

    ## setup of the environment

    ## determine database vendor
    $params{TYPE} = $config->get_xpath (
                   XPATH     => [ "common/$dbpath/type" ],
                   COUNTER   => [ 0 ],
                   CONFIG_ID => 'default',
    );
    ##! 16: 'type: ' . $params{TYPE}

    ## determine configuration for infrastructure
    $params{SERVER_ID} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/server_id" ],
                   COUNTER  => [ 0 ],
                   CONFIG_ID => 'default',
    );
    $params{SERVER_SHIFT} = $config->get_xpath (
                   XPATH     => [ "common/$dbpath/server_shift" ],
                   COUNTER   => [ 0 ],
                   CONFIG_ID => 'default',
    );

    ##! 16: 'server id: ' . $params{SERVER_ID}
    ##! 16: 'server shift: ' . $params{SERVER_ID}
    ## find configuration and detect number of options
    my ($vendor_name, $vendor_number, $vendor_envs) = ("", -1, 0);
    my $vendor_count = $config->get_xpath_count (
                            XPATH     => [ "common/$dbpath/environment/vendor" ],
                            COUNTER   => [],
                            CONFIG_ID => 'default',
    );
    for (my $k = 0; $k<$vendor_count; $k++)
    {
        $vendor_name = $config->get_xpath (
                            XPATH     => [ "common/$dbpath/environment/vendor", "type" ],
                            COUNTER   => [ $k, 0 ],
                            CONFIG_ID => 'default',
        );
        next if ($vendor_name ne $params{TYPE});
        $vendor_number = $k;
        eval { $vendor_envs = $config->get_xpath_count (
		   XPATH    => [ "common/$dbpath/environment/vendor", "option" ],
		   COUNTER  => [ $k ],
           CONFIG_ID => 'default',
       );
	};
    }
    ##! 16: 'vendor_envs: ' . $vendor_envs

    ## load environment
    for (my $i = 0; $i<$vendor_envs; $i++)
    {
        my $env_name = $config->get_xpath (
                           XPATH    => [ "common/$dbpath/environment/vendor", "option", "name" ],
                           COUNTER  => [ $vendor_number, $i, 0 ],
                           CONFIG_ID => 'default');
        my $env_value = $config->get_xpath (
                           XPATH    => [ "common/$dbpath/environment/vendor", "option", "value" ],
                           COUNTER  => [ $vendor_number, $i, 0 ],
                           CONFIG_ID => 'default');
        $ENV{$env_name} = $env_value;
        ##! 4: "NUMBER: $i"
        ##! 4: "OPTION: $env_name"
        ##! 4: "VALUE:  $env_value"
    }

    ## load database config
    $params{NAME} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/name" ],
                   COUNTER  => [ 0 ],
                   CONFIG_ID => 'default');
    ##! 16: 'name: ' . $params{NAME}
    eval{ $params{HOST} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/host" ],
                   COUNTER  => [ 0 ], CONFIG_ID => 'default') };
    eval{ $params{PORT} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/port" ],
                   COUNTER  => [ 0 ], CONFIG_ID => 'default') };
    eval{ $params{USER} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/user" ],
                   COUNTER  => [ 0 ], CONFIG_ID => 'default') };
    eval{ $params{PASSWD} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/passwd" ],
                   COUNTER  => [ 0 ], CONFIG_ID => 'default') };
    eval{ $params{NAMESPACE} = $config->get_xpath (
                   XPATH    => [ "common/$dbpath/namespace" ],
                   COUNTER  => [ 0 ], CONFIG_ID => 'default') };

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
    my $config = $current_xml_config;

    $config = $config->get_xpath (
                  XPATH    => [ 'common/log_config' ],
                  COUNTER  => [ 0 ],
                  CONFIG_ID => 'default');

    ## init logging
    ##! 64: 'before Log->new'

    my $log = OpenXPKI::Server::Log->new (CONFIG => $config);

    ##! 64: 'log during get_log: ' . $log

    return $log;
}

sub redirect_stderr
{
    ##! 1: "start"
    my $config = $current_xml_config;

    my $stderr = $config->get_xpath(
        XPATH     => "common/server/stderr",
        CONFIG_ID => 'default',
    );
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

## OpenXPKI::Server::API::Workflow.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project
## $Revision: 431 $

package OpenXPKI::Server::API::Workflow;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;
use Workflow::Factory;
use Data::Dumper;

use OpenXPKI::Debug 'OpenXPKI::Server::API::Workflow';
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::Observer::AddExecuteHistory;

my $workflow_table = 'WORKFLOW';
my $context_table  = 'WORKFLOW_CONTEXT';
my $workflow_history_table = 'WORKFLOW_HISTORY';

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

###########################################################################
# lowlevel workflow functions

sub list_workflow_instances {
    ##! 1: "start"
    my $self    = shift;
    my $arg_ref = shift;

    my $dbi = CTX('dbi_workflow');
    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    $dbi->commit();

    my $limit = $arg_ref->{LIMIT};
    ##! 16: 'limit: ' . $limit
    my $start = $arg_ref->{START};
    ##! 16: 'start: ' . $start

    my $instances = $dbi->select(
	TABLE   => $workflow_table,
	DYNAMIC => {
	    PKI_REALM  => CTX('session')->get_pki_realm(),
	},
        LIMIT   => {
            AMOUNT => $limit,
            START  => $start,
        },
        REVERSE => 1,
    );

    ##! 16: 'instances: ' . Dumper $instances
    return $instances;
}

sub get_number_of_workflow_instances {
    ##! 1: "start"
    my $self    = shift;
    my $arg_ref = shift;

    my $dbi = CTX('dbi_workflow');
    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    $dbi->commit();

    # TODO - wait for someone to implement aggregates without joins
    # and then use a simpler query (cf. feature request #1675572)
    my $instances = $dbi->select(
	TABLE     => [ $workflow_table ],
        JOIN      => [ [ 'WORKFLOW_SERIAL'] ],
	DYNAMIC   => {
	    PKI_REALM  => CTX('session')->get_pki_realm(),
	},
        COLUMNS   => [
            {
                COLUMN    => 'WORKFLOW_SERIAL',
                AGGREGATE => 'COUNT',
            }
        ],
    );

    ##! 16: 'instances: ' . Dumper $instances
    return $instances->[0]->{WORKFLOW_SERIAL};
}

sub list_context_keys {
    ##! 1: "start"
    my $self    = shift;
    my $arg_ref = shift;

    my $dbi = CTX('dbi_workflow');
    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    $dbi->commit();

    if (! defined $arg_ref->{'WORKFLOW_TYPE'}
               || $arg_ref->{'WORKFLOW_TYPE'} eq '') {
        $arg_ref->{'WORKFLOW_TYPE'} = '%';
    }
    my $context_keys = $dbi->select(
	TABLE    => [ $workflow_table, $context_table ],
        COLUMNS  => [
            {
                COLUMN   => $context_table . '.WORKFLOW_CONTEXT_KEY',
                DISTINCT => 1,
            },
        ],
	DYNAMIC => {
            "$workflow_table.WORKFLOW_TYPE" => $arg_ref->{'WORKFLOW_TYPE'}, 
	    "$workflow_table.PKI_REALM"  => CTX('session')->get_pki_realm(),
	},
        JOIN => [ [ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ] ],
    );
    ##! 16: 'context_keys: ' . Dumper $context_keys

    my @context_keys = map { $_->{$context_table.'.WORKFLOW_CONTEXT_KEY'}  } @{$context_keys};
    return \@context_keys;
}

sub list_workflow_titles {
    ##! 1: "list_workflow_titles"
    my $factory = __get_workflow_factory();

    # FIXME: we are poking into Workflow::Factory's internal data
    # structures here to get the required information.
    # There really should be accessor methods for this instead in the
    # Workflow class.
    my $result = {};
    if (ref $factory->{_workflow_config} eq 'HASH') {
	foreach my $item (keys %{$factory->{_workflow_config}}) {
	    my $type = $factory->{_workflow_config}->{$item}->{type};
	    my $desc = $factory->{_workflow_config}->{$item}->{description};
	    $result->{$type} = {
		description => $desc,
	    },
	}
    }
    return $result;
}

sub get_workflow_type_for_id {
    my $self    = shift;
    my $arg_ref = shift;
    my $id      = $arg_ref->{ID};
    ##! 1: 'start'
    ##! 16: 'id: ' . $id

    my $dbi = CTX('dbi_workflow');
    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    $dbi->commit();

    my $db_result = $dbi->first(
	TABLE    => $workflow_table,
	DYNAMIC  => {
            'WORKFLOW_SERIAL' => $id,
        },
    );
    if (! defined $db_result) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_WORKFLOW_TYPE_FOR_ID_NO_RESULT_FOR_ID',
            params  => {
                'ID' => $id,
            },
        );
    }
    my $type = $db_result->{'WORKFLOW_TYPE'};
    ##! 16: 'type: ' . $type
    return $type;
}

sub get_workflow_info {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "get_workflow_info"

    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    CTX('dbi_workflow')->commit();

    my $wf_title = $args->{WORKFLOW};
    my $wf_id    = $args->{ID};

    my $workflow = __get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);

    return __get_workflow_info($workflow);
}

sub execute_workflow_activity {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "execute_workflow_activity"

    my $wf_title    = $args->{WORKFLOW};
    my $wf_id       = $args->{ID};
    my $wf_activity = $args->{ACTIVITY};
    my $wf_params   = $args->{PARAMS};

    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    CTX('dbi_workflow')->commit();
    ##! 2: "load workflow"
    my $workflow = __get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);
    $workflow->delete_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $workflow->add_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');

    ##! 2: "check parameters"
    my %fields = ();
    foreach my $field ($workflow->get_action_fields($wf_activity))
    {
        $fields{$field->name()} = $field->description();
    }
    foreach my $key (keys %{$wf_params})
    {
        if (not exists $fields{$key})
        {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_SERVER_API_EXECUTE_WORKFLOW_ACTIVITY_ILLEGAL_PARAM",
	        params => {
		    WORKFLOW => $wf_title,
                    ID       => $wf_id,
                    ACTIVITY => $wf_activity,
                    PARAM    => $key,
                    VALUE    => $wf_params->{$key}
	        },
		log => {
		    logger => CTX('log'),
		    priority => 'error',
		    facility => 'system',
		},
		);
	}
    }

    ##! 2: "set parameters"
    my $context = $workflow->context();
    $context->param ($wf_params);

    ##! 64: Dumper $workflow
    eval {
        $workflow->execute_action($wf_activity);
    };
    if ($EVAL_ERROR) {
        my $eval = $EVAL_ERROR;
	my $log = {
	    logger => CTX('log'),
	    priority => 'error',
	    facility => 'system',
	};

        ## normal OpenXPKI exception
        $eval->rethrow() if (ref $eval eq "OpenXPKI::Exception");

        ## workflow exception
        my $error = $workflow->context->param('__error');
        if (defined $error)
        {
            if (ref $error eq '')
            {
                OpenXPKI::Exception->throw (
                    message => $error,
		    log     => $log,
		    );
            }
            if (ref $error eq 'ARRAY')
            {
                my @list = ();
                foreach my $item (@{$error})
                {
                    eval {
                        OpenXPKI::Exception->throw (
                            message => $item->[0],
                            params  => $item->[1]);
                    };
                    push @list, $EVAL_ERROR;
                }
                OpenXPKI::Exception->throw (
                    message  => "I18N_OPENXPKI_SERVER_API_EXECUTE_WORKFLOW_ACTIVITY_FAILED",
                    children => [ @list ],
		    log      => $log,
		    );
            }
        }

        ## unknown exception
        OpenXPKI::Exception->throw(
	    message => scalar $eval,
	    log     => $log,
	    );
    };
    ##! 64: Dumper $workflow

    CTX('log')->log(
	MESSAGE  => "Executed workflow activity '$wf_activity' on workflow id $wf_id (type '$wf_title')",
	PRIORITY => 'info',
	FACILITY => 'system',
	);

    return __get_workflow_info($workflow);
}

sub create_workflow_instance {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "create workflow instance"
    ##! 2: Dumper $args

    my $wf_title = $args->{WORKFLOW};

    # 'data only certificate request'
    my $workflow = __get_workflow_factory()->create_workflow($wf_title);

    if (! defined $workflow) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_ILLEGAL_WORKFLOW_TITLE",
	    params => {
		WORKFLOW => $wf_title,
	    });
    }
    $workflow->delete_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $workflow->add_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');

    my $creator = CTX('session')->get_user();
    ##! 2: $creator
    if (! defined $creator) {
	$creator = '';
    }

    $workflow->context->param(creator => $creator);

    # our convention is that every workflow MUST have the following properties:
    # - it must have an activity called 'create'
    # - it must have a state called 'CREATED' that is reached by executing
    #   'create'

    my $state = undef;
    eval
    {
        ##! 4: "determine the first action"
        my @list = $workflow->get_current_actions();
        if (not scalar @list)
        {
	    OpenXPKI::Exception->throw (
	        message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_NO_FIRST_ACTIVITY",
	        params => {
		    WORKFLOW => $wf_title,
	        });
        }
        ##! 4: "pass in specified parameters if available"
        if (exists $args->{PARAMS} &&
            (ref $args->{PARAMS} eq 'HASH'))
        {
            ##! 8: "load allowed parameters"
            ##! 32: '@list: ' . Dumper(\@list)
            ##! 64: 'workflow: ' . Dumper($workflow)
            my @activities = $workflow->get_current_actions();
            ##! 64: 'activity: ' . $list[0]
            my %fields = ();
            ##! 64: 'fields: ' . $workflow->get_action_fields($list[0])
            foreach my $field ($workflow->get_action_fields($list[0]))
            {
                ##! 32: 'field: ' . $field->name()
                $fields{$field->name()} = $field->description();
            }
            ##! 8: "store the allowed parameters"
	    foreach my $key (keys %{$args->{PARAMS}})
            {
                next if (not exists $fields{$key} and $args->{FILTER_PARAMS});
                if (not exists $fields{$key})
                {
                    OpenXPKI::Exception->throw (
                        message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_ILLEGAL_PARAM",
                        params => {
                                   WORKFLOW => $wf_title,
                                   ACTIVITY => $list[0],
                                   PARAM    => $key,
                                   VALUE    => $args->{PARAMS}->{$key}
                                  });
                }
	        $workflow->context->param($key => $args->{PARAMS}->{$key});
            }
        }
        $state = $workflow->execute_action($list[0]);
    };
    
    if ($EVAL_ERROR || $state eq 'INITIAL') {
        my $eval = $EVAL_ERROR;
        # ignore this special Workflow exception - we are stuck in a
        # state which should be autorun. This might happen if something
        # does not happen as fast as we want, but we can easily recover
        # by autorunning manually. This is for example used in the
        # SCEP code, which checks the state of the child every time
        # an SCEP message is received.
        # FIXME -- this should better be a patch to Workflow, to support
        # such "semi-automatic" states which don't complain ...
        if (ref $eval eq 'Workflow::Exception' &&
            ($eval->error() =~ m{State[ ].*[ ]should[ ]be[ ]automatically[ ]executed[ ]but[ ]+there[ ]are[ ]no[ ]actions[ ]available[ ]for[ ]execution\.}xms)) {
            ##! 2: 'ignoring error'
        }
        else {
            ##! 16: 'eval error: ' . $EVAL_ERROR
            my $error = $workflow->context->param('__error');
            if (defined $error) {
                if (ref $error eq '')
                {
                    OpenXPKI::Exception->throw (
                        message => $error);
                }
                if (ref $error eq 'ARRAY')
                {
                    my @list = ();
                    foreach my $item (@{$error})
                    {
                        eval {
                            OpenXPKI::Exception->throw (
                                message => $item->[0],
                                params  => $item->[1]);
                        };
                        push @list, $EVAL_ERROR;
                    }
                    OpenXPKI::Exception->throw (
                        message  => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_CREATE_FAILED",
                        children => [ @list ]);
                } 
            }
            if ($eval)
            {
                if (index ($eval, "The following fields require a value:") > -1)
                {
                    ## missing field(s) in workflow
                    $eval =~ s/^.*://;
                    OpenXPKI::Exception->throw (
                        message => "I18N_OPENXPKI_SERVER_API_WORKFLOW_MISSING_REQUIRED_FIELDS",
                        params  => {FIELDS => $eval});
                }
                $eval->rethrow();
            }
            OpenXPKI::Exception->throw (
                    message => 'I18N_WF_ERROR_ILLEGAL_STATE');
        };
    }        

    my $wf_id = $workflow->id();
    
    CTX('log')->log(
	MESSAGE  => "Workflow instance $wf_id created (type: '$wf_title')",
	PRIORITY => 'info',
	FACILITY => 'system',
	);

    return __get_workflow_info($workflow);
}

sub get_workflow_activities {
    my $self  = shift;
    my $args  = shift;

    my $wf_title = $args->{WORKFLOW};
    my $wf_id    = $args->{ID};

    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    CTX('dbi_workflow')->commit();

    my $workflow = __get_workflow_factory()->fetch_workflow(
	$wf_title,
	$wf_id);
    my @list = $workflow->get_current_actions();

    ##! 1: "finished"
    return \@list;
}

sub search_workflow_instances_count {
    my $self    = shift;
    my $arg_ref = shift;

    my $result = $self->search_workflow_instances($arg_ref);

    if (defined $result && ref $result eq 'ARRAY') {
        return scalar @{$result};
    }
    return 0;
}

sub search_workflow_instances {
    my $self     = shift;
    my $arg_ref  = shift;
    my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;

    my $dbi = CTX('dbi_workflow');
    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    $dbi->commit();

    my $realm = CTX('session')->get_pki_realm();

    if (scalar @{$arg_ref->{CONTEXT}} == 0) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_NEED_AT_LEAST_ONE_CONTEXT_ENTRY',
        );
    }
    my $dynamic;
    my @tables;
    my @joins;
    ## create complex select structures, similar to the following:
    # $dbi->select(
    #    TABLE    => [ { WORKFLOW_CONTEXT => WORKFLOW_CONTEXT_0},
    #                  { WORKFLOW_CONTEXT => WORKFLOW_CONTEXT_1},
    #                  WORKFLOW
    #                ],
    #    COLUMNS   => ...
    #    JOIN      => [ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ],
    #    DYNAMIC   => {
    #                   WORKFLOW_CONTEXT_0.WORKFLOW_CONTEXT_KEY => $key1,
    #                   WORKFLOW_CONTEXT_0.WORKFLOW_CONTEXT_VALUE => $value1,
    #                   WORKFLOW_CONTEXT_1.WORKFLOW_CONTEXT_KEY => $key2,
    #                   WORKFLOW_CONTEXT_1.WORKFLOW_CONTEXT_VALUE => $value2,
    #                   WORKFLOW.PKI_REALM = $realm,
    #                 },
    # );
    my $i = 0;
    foreach my $context_entry (@{$arg_ref->{CONTEXT}}) {
        my $table_alias = $context_table . '_' . $i;
        my $key   = $context_entry->{KEY};
        my $value = $context_entry->{VALUE};
        $dynamic->{$table_alias . '.WORKFLOW_CONTEXT_KEY'}   = $key;
        $dynamic->{$table_alias . '.WORKFLOW_CONTEXT_VALUE'} = $value;
        push @tables, [ $context_table => $table_alias ];
        push @joins, 'WORKFLOW_SERIAL';
        $i++;
    }
    push @tables, $workflow_table;
    push @joins, 'WORKFLOW_SERIAL';
    $dynamic->{$workflow_table . '.PKI_REALM'} = $realm;

    if (defined $arg_ref->{TYPE}) {
        # do parameter validation (here instead of the API because
        # the API can't do regex checks on arrayrefs)
        if (! ref $arg_ref->{TYPE}) {
            if ($arg_ref->{TYPE} !~ $re_alpha_string) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_TYPE_NOT_ALPHANUMERIC',
                    params  => {
                        TYPE => $arg_ref->{TYPE},
                    },
                );
            }
        }
        elsif (ref $arg_ref->{TYPE} eq 'ARRAYREF') {
            foreach my $subtype (@{$arg_ref->{TYPE}}) {
                if ($subtype !~ $re_alpha_string) {
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_TYPE_NOT_ALPHANUMERIC',
                        params  => {
                            TYPE => $subtype,
                        },
                    );
                }
            }
        }
        $dynamic->{$workflow_table . '.WORKFLOW_TYPE'} = $arg_ref->{TYPE};
    }
    if (defined $arg_ref->{STATE}) {
        if (! ref $arg_ref->{STATE}) {
            if ($arg_ref->{STATE} !~ $re_alpha_string) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_STATE_NOT_ALPHANUMERIC',
                    params  => {
                        STATE => $arg_ref->{STATE},
                    },
                );
            }
        }
        elsif (ref $arg_ref->{STATE} eq 'ARRAYREF') {
            foreach my $substate (@{$arg_ref->{STATE}}) {
                if ($substate !~ $re_alpha_string) {
                    OpenXPKI::Exception->throw(
                        message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_STATE_NOT_ALPHANUMERIC',
                        params  => {
                            STATE => $substate,
                        },
                    );
                }
            }
        }
        $dynamic->{$workflow_table . '.WORKFLOW_STATE'} = $arg_ref->{STATE};
    }
    my %limit;
    if (defined $arg_ref->{LIMIT} && !defined $arg_ref->{START}) {
        $limit{'LIMIT'} = $arg_ref->{LIMIT};
    }
    elsif (defined $arg_ref->{LIMIT} && defined $arg_ref->{START}) {
        $limit{'LIMIT'} = {
            AMOUNT => $arg_ref->{LIMIT},
            START  => $arg_ref->{START},
        };
    }

    ##! 16: 'dynamic: ' . Dumper $dynamic
    ##! 16: 'tables: ' . Dumper(\@tables)
    my $result = $dbi->select(
	TABLE   => \@tables,
        COLUMNS => [
                         $workflow_table . '.WORKFLOW_LAST_UPDATE',
                         $workflow_table . '.WORKFLOW_SERIAL',
                         $workflow_table . '.WORKFLOW_TYPE',
                         $workflow_table . '.WORKFLOW_STATE',
                   ],
        JOIN    => [
                         \@joins,
                   ],
        REVERSE => 1,
	DYNAMIC => $dynamic,
        %limit,
    );
    ##! 16: 'result: ' . Dumper $result
    return $result;
}
 
###########################################################################
# private functions

sub __get_workflow_factory {
    my $args  = shift;

    ##! 1: "__get_workflow_factory"

    my $workflow_factory = Workflow::Factory->instance();


    my $pki_realm = CTX('session')->get_pki_realm();
    my $pki_realm_index;
    
    my $pki_realm_count = CTX('xml_config')->get_xpath_count (XPATH => "pki_realm");

  FINDREALM:
    for (my $ii = 0; $ii < $pki_realm_count; $ii++)
    {
        if (CTX('xml_config')->get_xpath (XPATH   => ["pki_realm", "name"],
					  COUNTER => [$ii,         0])
	    eq $pki_realm) {

            $pki_realm_index = $ii;
	    last FINDREALM;
        }
    }

    if (! defined $pki_realm_index) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_API_GET_WORKFLOW_FACTORY_INCORRECT_PKI_REALM");
    }

    my %workflow_config = (
	# how we name it in our XML configuration file
	workflows => {
	    # how the parameter is called for Workflow::Factory 
	    factory_param => 'workflow',
	},
	activities => {
	    factory_param => 'action',
	},
	validators => {
	    factory_param => 'validator',
	},
	conditions => {
	    factory_param => 'condition',
	},
	);
    
    foreach my $type (keys %workflow_config) {
	##! 2: "getting workflow '$type' configuration files"

	my $count;
	eval {
	    $count = CTX('xml_config')->get_xpath_count(
		XPATH =>   [ 'pki_realm',      'workflow_config', $type, 'configfile' ],
		COUNTER => [ $pki_realm_index, 0,                 0,      ],
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
	} elsif ($EVAL_ERROR && (ref $EVAL_ERROR)) {
	    $EVAL_ERROR->rethrow();
	}

	if (! defined $count) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_API_GET_WORKFLOW_FACTORY_MISSING_WORKFLOW_CONFIGURATION",
		params => {
		    configtype => $type,
		});
	}


	for (my $ii = 0; $ii < $count; $ii++) {
	    my $entry = CTX('xml_config')->get_xpath (
		XPATH   => [ 'pki_realm', 'workflow_config', $type, 'configfile' ],
		COUNTER => [ $pki_realm_index, 0,            0,     $ii ],
		);
	    ##! 4: "config file: $entry"
	    $workflow_factory->add_config_from_file(
		$workflow_config{$type}->{factory_param}  => $entry,
		);
	}
    }

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

    ##! 64: Dumper $workflow_factory

    return $workflow_factory;
}


sub __get_workflow_info {
    my $workflow  = shift;

    ##! 1: "__get_workflow_info"

    ##! 64: Dumper $workflow

    my $result = {
	WORKFLOW => {
	    ID          => $workflow->id(),
	    STATE       => $workflow->state(),
	    TYPE        => $workflow->type(),
	    DESCRIPTION => $workflow->description(),
	    LAST_UPDATE => $workflow->last_update(),
	    CONTEXT => { 
		%{$workflow->context()->param()} 
	    },
	},
    };
    
    foreach my $activity ($workflow->get_current_actions()) {
	##! 2: $activity

	# FIXME - bug in Workflow::Action (v0.17)?: if no fields are defined the
	# method tries to return an arrayref on an undef'd value
	my @fields;
	eval {
	    @fields = $workflow->get_action_fields($activity);
	};
	
	foreach my $field (@fields) {
	    ##! 4: $field->name()
	    $result->{ACTIVITY}->{$activity}->{FIELD}->{$field->name()} =
	    {
		DESCRIPTION => $field->description(),
		REQUIRED    => $field->is_required(),
	    };
	}
    }


    return $result;
}

1;
__END__

=head1 Name

OpenXPKI::Server::API::Workflow

=head1 Description

This is the workflow interface which should be used by all user interfaces of OpenXPKI.
A user interface MUST NOT access the server directly. The only allowed
access is via this API. Any function which is not available in this API is
not for public use.
The API gets access to the server via the 'server' context object. This
object must be set before instantiating the API.

=head1 Functions

=head2 new

Default constructor created by Class::Std.

=head2 list_workflow_titles

Returns a hash ref containing all available workflow titles including
a description.

Return structure:
{
  title => description,
  ...
}

=head2 search_workflow_instances

This function accesses the database directly in order to find
Workflow instances matching the specified search criteria.

Returns an array reference of the database query result.

Named parameters:

=over

=item * CONTEXT

The named parameter CONTEXT must be a hash reference.
Apply search filter to search using the KEY/VALUE pair passed in
CONTEXT and match all Workflow instances whose context contain all
of the specified tuples.
It is possible to use SQL wildcards such as % in the VALUE field.

=back

Examples:

  my @workflow_ids = $api->search_workflow_instances(
      {
	  CONTEXT =>
	      {
		  KEY   => 'SCEP_TID',
		  VALUE => 'ECB001D912E2A357E6E813D87A72E641',
	      },
      }

=over

=item * TYPE (optional)

The named parameter TYPE can either be scalar or an array reference.
Searches for workflows only of this type / these types.

=item * STATE (optional)

The named parameter TYPE can either be scalar or an array reference.
Searches for workflows only in this state / these states.

=item * LIMIT (optional)

If given, limits the amount of workflows returned.

=item * START (optional)

If given, defines the offset of the returned workflow (use with LIMIT).

=back

=head2 search_workflow_instances_count

Works exactly the same as search_workflow_instances, but returns the
number of results instead of the results themselves.


## OpenXPKI::Server::API::Workflow.pm 
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

package OpenXPKI::Server::API::Workflow;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;
use Workflow::Factory;
use Data::Dumper;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Workflow::Observer::AddExecuteHistory;
use OpenXPKI::Server::Workflow::Observer::Log;
use OpenXPKI::Serialization::Simple;

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

sub get_cert_identifier_by_csr_wf {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;
    my $wf_id   = $arg_ref->{WORKFLOW_ID};

    my $factory = __get_workflow_factory({
        WORKFLOW_ID => $wf_id,
    });
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_CERT_IDENTIFIER_BY_CSR_WF_FACTORY_NOT_DEFINED',
            params  => {
                'WORKFLOW_ID' => $wf_id,
            },
        );
    }
    my $workflow = $factory->fetch_workflow(
	    'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_SIGNING_REQUEST',
	    $wf_id,
    );
    if (! defined $workflow) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_CERT_IDENTIFIER_BY_CSR_WF_WORKFLOW_COULD_NOT_BE_FETCHED',
            params  => {
                'WORKFLOW_ID' => $wf_id,
            },
        );
    }
    my $wf_children_ser = $workflow->context->param('wf_children_instances');
    if (! defined $wf_children_ser) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_CERT_IDENTIFIER_BY_CSR_WF_NO_CHILDREN_INSTANCES_FOUND',
            params  => {
                'WORKFLOW_ID' => $wf_id,
            },
        );
    }
    my $wf_children;
    eval {
        $wf_children = OpenXPKI::Serialization::Simple->new()->deserialize($wf_children_ser);
    };
    if (! defined $wf_children) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_CERT_IDENTIFIER_BY_CSR_WF_DESERIALIZING_WF_CHILDREN_CONTEXT_PARAMETER_FAILED',
            params  => {
                'WORKFLOW_ID' => $wf_id,
                'SERIALIZED'  => $wf_children_ser,
            },
        );
    }
    my $child_type;
    eval {
        $child_type = $wf_children->[0]->{TYPE};
    };
    my $child_id;
    eval {
        $child_id = $wf_children->[0]->{ID};
    };
    if (! defined $child_id || ! defined $child_type) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_CERT_IDENTIFIER_BY_CSR_WF_COULD_NOT_DETERMINE_CHILD_TYPE_AND_ID',
            params  => {
                'WORKFLOW_ID' => $wf_id,
                'CHILDREN'    => $wf_children,
            },
        );
    }
    $factory = __get_workflow_factory({
        WORKFLOW_ID => $child_id,
    });
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_CERT_IDENTIFIER_BY_CSR_WF_CHILD_FACTORY_NOT_DEFINED',
            params  => {
                'WORKFLOW_CHILD_ID' => $child_id,
            },
        );
    }
    $workflow = $factory->fetch_workflow(
	    $child_type,
	    $child_id,
    );
    if (! defined $workflow) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_CERT_IDENTIFIER_BY_CSR_WF_CHILD_WORKFLOW_COULD_NOT_BE_FETCHED',
            params  => {
                'WORKFLOW_CHILD_ID'   => $child_id,
                'WORKFLOW_CHILD_TYPE' => $child_type,
            },
        );
    }
    my $cert_identifier;
    eval {
        $cert_identifier = $workflow->context->param('cert_identifier');
    };
    return $cert_identifier;
}

sub get_config_id {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    # determine workflow's config ID
    CTX('dbi_workflow')->commit();
    my $wf = CTX('dbi_workflow')->first(
        TABLE   => 'WORKFLOW_CONTEXT',
        DYNAMIC => {
            'WORKFLOW_SERIAL'      => $arg_ref->{ID},
            'WORKFLOW_CONTEXT_KEY' => 'config_id',
        },
    );
    return $wf->{WORKFLOW_CONTEXT_VALUE};
}

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
             $context_table . '.WORKFLOW_CONTEXT_KEY',
        ],
	    DYNAMIC => {
            "$workflow_table.WORKFLOW_TYPE" => $arg_ref->{'WORKFLOW_TYPE'}, 
	        "$workflow_table.PKI_REALM"     => CTX('session')->get_pki_realm(),
	    },
        JOIN => [ [ 'WORKFLOW_SERIAL', 'WORKFLOW_SERIAL' ] ],
        DISTINCT => 1,
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

    if (! defined $wf_title) {
        $wf_title = $self->get_workflow_type_for_id({ ID => $wf_id });
    }

    # get the factory corresponding to the workflow
    my $factory = __get_workflow_factory({
        WORKFLOW_ID => $wf_id,
    });
    my $workflow = $factory->fetch_workflow(
	    $wf_title,
	    $wf_id
    );

    return __get_workflow_info($workflow);
}

sub get_workflow_history {
    my $self    = shift;
    my $arg_ref = shift;
    ##! 1: 'start'

    my $wf_id   = $arg_ref->{ID};

    my $history = CTX('dbi_workflow')->select(
        TABLE => $workflow_history_table,
        DYNAMIC => {
            WORKFLOW_SERIAL => $wf_id,
        },
    );
    # sort ascending (unsorted within seconds)
    @{$history} = sort { $a->{WORKFLOW_HISTORY_SERIAL} <=> $b->{WORKFLOW_HISTORY_SERIAL} } @{$history};
    ##! 64: 'history: ' . Dumper $history

    return $history;
}

sub execute_workflow_activity {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "execute_workflow_activity"

    my $wf_title    = $args->{WORKFLOW};
    my $wf_id       = $args->{ID};
    my $wf_activity = $args->{ACTIVITY};
    my $wf_params   = $args->{PARAMS};

    if (! defined $wf_title) {
        $wf_title = $self->get_workflow_type_for_id({ ID => $wf_id });
    }
    # commit to get a current snapshot of the database in the
    # highest isolation level.
    # Without this, we will only see old data, especially if
    # other processes are writing to the database at the same time
    CTX('dbi_workflow')->commit();
    ##! 2: "load workflow"
    my $factory = __get_workflow_factory({
        WORKFLOW_ID => $wf_id,
    });
    my $workflow = $factory->fetch_workflow(
	    $wf_title,
	    $wf_id
    );
    $workflow->delete_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $workflow->add_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $workflow->delete_observer ('OpenXPKI::Server::Workflow::Observer::Log');
    $workflow->add_observer ('OpenXPKI::Server::Workflow::Observer::Log');

    ##! 2: "check parameters"
    my %fields = ();
    if (scalar keys %{ $wf_params } > 0) {
        # only call get_action_fields if parameters are actually passed
        # this especially helps with the call to the
        # CheckForkedWorkflowChildren condition - get_action_fields
        # evaluates the condition even though the activity class is
        # called without any parameters.
        foreach my $field ($workflow->get_action_fields($wf_activity))
        {
            $fields{$field->name()} = $field->description();
        }
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

sub get_workflow_activities_params {
	my $self = shift;
	my $args = shift;
	my @list = ();

	my $wf_title = $args->{WORKFLOW};
	my $wf_id = $args-> {ID};

	# Commit to get a current snapshot and avoid old data
	CTX('dbi_workflow')->commit();

	my $factory = __get_workflow_factory({
			WORKFLOW_ID => $wf_id,
		});

	my $workflow = $factory->fetch_workflow(
		$wf_title,
		$wf_id,
	);

	foreach my $action ( $workflow->get_current_actions() ) {
		my $fields = [];
		foreach my $field ($workflow->get_action_fields( $action ) ) {
			push @{ $fields }, {
				'name'		=> $field->name(),
				'label'		=> $field->label(),
				'description'	=> $field->description(),
				'type'		=> $field->type(),
				'requirement'	=> $field->requirement(),
			};
		};
		push @list, $action, $fields;
	}
	return \@list;
}


sub create_workflow_instance {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "create workflow instance"
    ##! 2: Dumper $args

    my $wf_title = $args->{WORKFLOW};

    CTX('acl')->authorize_workflow({
        ACTION => 'create',
        TYPE   => $wf_title,
    });

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
    $workflow->delete_observer ('OpenXPKI::Server::Workflow::Observer::Log');
    $workflow->add_observer ('OpenXPKI::Server::Workflow::Observer::Log');

    my $creator = CTX('session')->get_user();
    ##! 2: $creator
    if (! defined $creator) {
	$creator = '';
    }

    $workflow->context->param(creator => $creator);

    my $config_id = CTX('api')->get_current_config_id();
    if (! defined $config_id) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_CREATE_WORKFLOW_CONFIG_ID_UNDEFINED',
        );
    }

    $workflow->context->param(config_id => $config_id);

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

            # store workflow parent ID and delete it from the arguments
            $workflow->context->param('workflow_parent_id' => delete($args->{PARAMS}->{'workflow_parent_id'}));

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
            if (ref $eval eq 'OpenXPKI::Exception') {
                $eval->rethrow();
            }
            else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_CREATE_FAILED_EVAL_ERROR',
                    params  => {
                        ERROR => "$eval",
                    },
                );
            }
        }
        OpenXPKI::Exception->throw (
                message => 'I18N_WF_ERROR_ILLEGAL_STATE');
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

    my $factory = __get_workflow_factory({
        WORKFLOW_ID => $wf_id,
    });
    my $workflow = $factory->fetch_workflow(
	    $wf_title,
	    $wf_id,
    );
    my @list = $workflow->get_current_actions();

    ##! 128: 'workflow after get_workflow_activities: ' . Dumper $workflow

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

    my @context = ();
    eval {
        @context = @{ $arg_ref->{CONTEXT} };
    };
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
    foreach my $context_entry (@context) {
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
        COLUMNS  => [
                         $workflow_table . '.WORKFLOW_LAST_UPDATE',
                         $workflow_table . '.WORKFLOW_SERIAL',
                         $workflow_table . '.WORKFLOW_TYPE',
                         $workflow_table . '.WORKFLOW_STATE',
                    ],
        JOIN     => [
                         \@joins,
                    ],
        REVERSE  => 1,
	    DYNAMIC  => $dynamic,
        DISTINCT => 1,
        ORDER => [
            $workflow_table . '.WORKFLOW_SERIAL',
        ],
        %limit,
    );
    ##! 16: 'result: ' . Dumper $result
    return $result;
}
 
###########################################################################
# private functions

sub __get_workflow_factory {
    ##! 1: 'start'
    my $arg_ref = shift;
    my $current_config_id = CTX('api')->get_current_config_id();
    my $config_id = $current_config_id;
    if ($arg_ref->{CONFIG_ID}) {
        $config_id = $arg_ref->{CONFIG_ID};
    }
    if ($arg_ref->{WORKFLOW_ID}) {
        ##! 16: 'determine factory for workflow ' . $arg_ref->{WORKFLOW_ID}
        # determine workflow's config ID and set config_id accordingly
        my $wf = CTX('dbi_workflow')->first(
            TABLE   => 'WORKFLOW_CONTEXT',
            DYNAMIC => {
                'WORKFLOW_SERIAL'      => $arg_ref->{WORKFLOW_ID},
                'WORKFLOW_CONTEXT_KEY' => 'config_id',
            },
        );
        if (! defined $wf) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_API_GET_WORKFLOW_FACTORY_CONFIG_ID_CONTEXT_ENTRY_COULD_NOT_BE_FOUND',
                params  => {
                    WORKFLOW_ID => $arg_ref->{WORKFLOW_ID},
                },
            );
        }
        $config_id = $wf->{WORKFLOW_CONTEXT_VALUE};
    }
    ##! 32: 'config_id: ' . $config_id
    my $pki_realm = CTX('session')->get_pki_realm();
    if ($arg_ref->{PKI_REALM}) {
        $pki_realm = $arg_ref->{PKI_REALM};
    }
    ##! 32: 'realm: ' . $pki_realm

    # We have now obtained the configuration id that was active during
    # creation of the workflow instance. However, if for some reason
    # the matching configuration is not available we have two options:
    # 1. bail out with an error
    # 2. accept that there is an error and continue anyway with a different
    #    configuration
    # Option 1 is not ideal: if the corresponding configuration has for
    # some reason be deleted from the database the workflow cannot be
    # instantiated any longer. This is often not really a problem but
    # sometimes this will lead to severe problems, e. g. for long 
    # running workflows. unfortunately, if a workflow cannot be instantiated
    # it can neither be displayed, nor executed.
    # In order to make things a bit more robust fall back to using a newer
    # configuration than the one missing. As we don't have a timestamp
    # for the configuration, a safe bet is to use the current configuration.
    # Caveat: the current workflow definition might not be compatible with
    # the particular workflow instance. There is a risk that the workflow
    # instance gets stuck in an unreachable state.
    # In comparison to not being able to even view the workflow this seems
    # to be an acceptable tradeoff.

    my $factory;
    if (defined CTX('workflow_factory')->{$config_id}->{$pki_realm}) {
	# use workflow factory as defined in workflow context
	$factory = CTX('workflow_factory')->{$config_id}->{$pki_realm};
    } else {
 	# use current workflow definition
	$factory = CTX('workflow_factory')->{$current_config_id}->{$pki_realm};

	CTX('log')->log(
	    MESSAGE  => 'Workflow ID ' . $arg_ref->{WORKFLOW_ID} . ' references unavailable config ID ' . $config_id . ' (falling back to current configuration ID ' . $current_config_id . ')',
	    PRIORITY => 'warn',
	    FACILITY => 'system',
	    );
    }
    
    ##! 64: 'factory: ' . Dumper $factory
    ##! 64: 'workflow_factory keys: ' . Dumper keys %{ CTX('workflow_factory') }
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_WORKFLOW_FACTORY_FACTORY_NOT_DEFINED',
        );
    }
    # this is a hack, because Workflow::Factory does not really
    # support subclassing (although it claims so). For details see
    # Server::Init::__wf_factory_add_config()
    no warnings 'redefine';
    *Workflow::State::FACTORY   = sub { return $factory };
    *Workflow::Action::FACTORY  = sub { return $factory };
    *Workflow::Factory::FACTORY = sub { return $factory };
    *Workflow::FACTORY          = sub { return $factory };
    *OpenXPKI::Server::Workflow::Observer::AddExecuteHistory::FACTORY
        = sub { return $factory };
    return $factory;
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

=head2 get_config_id

Looks up the configuration ID for a given workflow ID (passed with the
named parameter 'ID') from the database.

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


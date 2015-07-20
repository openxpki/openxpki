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

sub START {
    # somebody tried to instantiate us, but we are just an
    # utility class with static methods
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_SUBCLASSES_CAN_NOT_BE_INSTANTIATED',
    );
}

###########################################################################
# lowlevel workflow functions
  
sub list_workflow_titles {
    ##! 1: "list_workflow_titles"
    return __get_workflow_factory()->list_workflow_titles();
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
    TABLE    => 'WORKFLOW',
    DYNAMIC  => {
            'WORKFLOW_SERIAL' => {VALUE => $id},
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
    return $self->__get_workflow_ui_info( $args );
}


=head2 get_workflow_ui_info

Return a hash with the information taken from the workflow engine plus
additional information taken from the workflow config via connector.
Expects one of:

=over

=item ID numeric workflow id

=item TYPE workflow type

=item WORKFLOW workflow object

=back

=cut
sub __get_workflow_ui_info {

    ##! 1: 'start'

    my $self  = shift;
    my $args  = shift;

    my $factory;
    my $result = {};

    # initial info receives a workflow title
    my ($wf_description, $wf_state);
    my @activities;
    if (!$args->{ID} && !$args->{WORKFLOW}) {

        if (!$args->{TYPE}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_WORKFLOW_INFO_NO_WORKFLOW_GIVEN',
                params => { ARGS => $args }
            );
        }

        # TODO we might use the OpenXPKI::Workflow::Config object for this
        # Note: Using create_workflow shreds a workflow id and creates an orphaned entry in the history table
        $factory = CTX('workflow_factory')->get_factory();
        my $wf_config = $factory->_get_workflow_config($args->{TYPE});
        # extract the action in the initial state from the config
        foreach my $state (@{$wf_config->{state}}) {
            next if ($state->{name} ne 'INITIAL');
            @activities = ($state->{action}->[0]->{name});
            last;
        }

        $result->{WORKFLOW} = {
            TYPE        => $args->{TYPE},
            ID          => 0,
            STATE       => 'INITIAL',
        };

    } else {

        my $workflow;
        if ($args->{ID}) {
            $workflow = CTX('workflow_factory')->get_workflow({ ID => $args->{ID}} );
        } else {
            $workflow = $args->{WORKFLOW};
        }
        
        ##! 32: 'Workflow raw result ' . Dumper $workflow
        
        $factory = $workflow->factory();

        $result->{WORKFLOW} = {
            ID          => $workflow->id(),
            STATE       => $workflow->state(),
            TYPE        => $workflow->type(),
            LAST_UPDATE => $workflow->last_update(),
            PROC_STATE  => $workflow->proc_state(),
            COUNT_TRY   => $workflow->count_try(),
            WAKE_UP_AT  => $workflow->wakeup_at(),
            REAP_AT     => $workflow->reap_at(),
            CONTEXT     => { %{$workflow->context()->param() } },
        };
        
        $result->{HANDLES} = $workflow->get_global_actions();   

        ##! 32: 'Workflow result ' . Dumper $result
        if ($args->{ACTIVITY}) {
            @activities = ( $args->{ACTIVITY} );
        } else {
            @activities = $workflow->get_current_actions();
        }
    }

    $result->{ACTIVITY} = {};
    foreach my $wf_action (@activities) {
        $result->{ACTIVITY}->{$wf_action} = $factory->get_action_info( $wf_action, $result->{WORKFLOW}->{TYPE} );
    }

    # Add Workflow UI Info
    my $head = CTX('config')->get_hash([ 'workflow', 'def', $result->{WORKFLOW}->{TYPE}, 'head' ]);
    $result->{WORKFLOW}->{label} = $head->{label};
    $result->{WORKFLOW}->{description} = $head->{description};

    # Add State UI Info
    my $ui_state = CTX('config')->get_hash([ 'workflow', 'def', $result->{WORKFLOW}->{TYPE}, 'state', $result->{WORKFLOW}->{STATE} ]);
    my @ui_state_out;
    if ($ui_state->{output}) {
        if (ref $ui_state->{output} eq 'ARRAY') {
            @ui_state_out = @{$ui_state->{output}};
        } else {
            @ui_state_out = CTX('config')->get_list([ 'workflow', 'def', $result->{WORKFLOW}->{TYPE}, 'state', $result->{WORKFLOW}->{STATE}, 'output' ]);
        }
        
        $ui_state->{output} = [];
        foreach my $field (@ui_state_out) {           
            # Load the field definitions
            push @{$ui_state->{output}}, $factory->get_field_info($field, $result->{WORKFLOW}->{TYPE} );
        }
    } 
    
    # Info for buttons       
    $result->{STATE} = $ui_state;

    my $button = $result->{STATE}->{button};
    $result->{STATE}->{button} = {};
    delete $result->{STATE}->{action};


    # Add the possible options (=activity names) in the right order
    my @options = CTX('config')->get_scalar_as_list([ 'workflow', 'def', $result->{WORKFLOW}->{TYPE},  'state', $result->{WORKFLOW}->{STATE}, 'action' ]);

    # Check defined actions against possible ones, non global actions are prefixed
    $result->{STATE}->{option} = [];

    ##! 16: 'Testing actions ' .  Dumper \@options
    foreach my $option (@options) {

        $option =~ m{ \A (((global_)?)([^\s>]+))}xs;
        $option = $1;
        my $option_base = $4;
        
        my $action;
        if ($3) { # global or not
            $action = 'global_'.$option_base;
        } else {
            $action = $head->{prefix}.'_'.$option_base;
        }
        ##! 16: 'Activity ' . $action
        ##! 64: 'Available actions ' . Dumper keys %{$result->{ACTIVITY}}
        if ($result->{ACTIVITY}->{$action}) {
            push @{$result->{STATE}->{option}}, $action;
        }

        # Add button config if available
        $result->{STATE}->{button}->{$action} = $button->{$option} if ($button->{$option});
    }
    
    # Add button markup (Head)
    if ($button->{_head}) {
        $result->{STATE}->{button}->{_head} = $button->{_head};
    } 
     
    return $result;

}

sub get_workflow_history {
    my $self    = shift;
    my $arg_ref = shift;
    ##! 1: 'start'

    my $wf_id   = $arg_ref->{ID};

    my $history = CTX('dbi_workflow')->select(
        TABLE => 'WORKFLOW_HISTORY',
        DYNAMIC => {
            WORKFLOW_SERIAL => {VALUE => $wf_id},
        },
        ORDER => [ 'WORKFLOW_HISTORY_DATE', 'WORKFLOW_HISTORY_SERIAL' ]
    );
    # sort ascending (unsorted within seconds)
    #@{$history} = sort { $a->{WORKFLOW_HISTORY_SERIAL} <=> $b->{WORKFLOW_HISTORY_SERIAL} } @{$history};
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
    my $wf_uiinfo  = $args->{UIINFO};

    ##! 32: 'params ' . Dumper $wf_params

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

    $workflow->reload_observer();

    # check the input params
    my $params = $self->__validate_input_param( $workflow, $wf_activity, $wf_params );
    ##! 16: 'activity params ' . $params

    my $context = $workflow->context();
    $context->param ( $params ) if ($params);

    ##! 64: Dumper $workflow

    $self->__execute_workflow_activity( $workflow, $wf_activity );

    CTX('log')->log(
        MESSAGE  => "Executed workflow activity '$wf_activity' on workflow id $wf_id (type '$wf_title')",
        PRIORITY => 'info',
        FACILITY => 'workflow',
    );

    if ($wf_uiinfo) {
        return $self->__get_workflow_ui_info({ WORKFLOW => $workflow });
    } else {
        return __get_workflow_info($workflow);
    }
}

sub fail_workflow {
    
    my $self  = shift;
    my $args  = shift;

    ##! 1: "execute_workflow_activity"

    my $wf_title  = $args->{WORKFLOW};
    my $wf_id     = $args->{ID};
    my $reason    = $args->{REASON};
    my $error     = $args->{ERROR};
    
    if (! defined $wf_title) {
        $wf_title = $self->get_workflow_type_for_id({ ID => $wf_id });
    }

    CTX('dbi_workflow')->commit();
    ##! 2: "load workflow"
    my $factory = __get_workflow_factory({
        WORKFLOW_ID => $wf_id,
    });
    
    my $workflow = $factory->fetch_workflow(
        $wf_title,
        $wf_id
    );
    
    if (!$error) { $error = 'Failed by user'; }
    if (!$reason) { $reason = 'userfail'; }
    
    $workflow->set_failed( $error, $reason );
    
    return $self->__get_workflow_ui_info({ WORKFLOW => $workflow });
    
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

=head2 create_workflow_instance

Limitations and Requirements:

Each workflow MUST start with a state called INITIAL and MUST have exactly
one action. The factory presets the context value for creator with the current
session user, the inital action SHOULD set the context value 'creator' to the
id of the (associated) user of this workflow if this differs from the system
user. Note that the creator is afterwards attached to the workflow
as attribtue and would not update if you set the context value later!

Workflows that fail on complete the inital action are NOT saved and can not
be continued.

=cut
sub create_workflow_instance {
    my $self  = shift;
    my $args  = shift;

    ##! 1: "create workflow instance"
    ##! 2: Dumper $args

    my $wf_title = $args->{WORKFLOW};
    my $wf_uiinfo = $args->{UIINFO};

    my $workflow = __get_workflow_factory()->create_workflow($wf_title);

    if (! defined $workflow) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_ILLEGAL_WORKFLOW_TITLE",
            params => { WORKFLOW => $wf_title }
        );
    }

    $workflow->reload_observer();

    ## init creator
    my $wf_id = $workflow->id();
    my $context = $workflow->context();
    my $creator = CTX('session')->get_user();
    $context->param( 'creator'  => $creator );
    $context->param( 'creator_role'  => CTX('session')->get_role() );

    # This is crucial and must be done before the first execute as otherwise 
    # workflow acl fails when the first non-initial action is autorun
    $workflow->attrib({ creator => $creator });

    ##! 16: 'workflow id ' .  $wf_id
    CTX('log')->log(
        MESSAGE  => "Workflow instance $wf_id created for $creator (type: '$wf_title')",
        PRIORITY => 'info',
        FACILITY => 'workflow',
    );


    # load the first state and check for the initial action
    my $state = undef;

    my @actions = $workflow->get_current_actions();
    if (not scalar @actions || scalar @actions != 1) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_NO_FIRST_ACTIVITY",
            params => { WORKFLOW => $wf_title }
        );
    }
    my $initial_action = shift @actions;

    ##! 8: "initial action: " . $initial_action

    # check the input params
    my $params = $self->__validate_input_param( $workflow, $initial_action, $args->{PARAMS} );
    ##! 16: ' initial params ' . Dumper  $params

    $context->param ( $params ) if ($params);

    ##! 64: Dumper $workflow

    $self->__execute_workflow_activity( $workflow, $initial_action );

    # FIXME - ported from old factory but I do not understand if this ever can happen..
    # From theory, the workflow should throw an exception if the action can not be handled
    # Workflow is still in initial state - so something went wrong.
    if ($workflow->state() eq 'INITIAL') {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_CREATE_FAILED",
            log =>  {
                logger => CTX('log'),
                priority => 'error',
                facility => [ 'system', 'workflow' ]
            }
        );
    }

    # check back for the creator in the context and copy it to the attribute table
    # doh - somebody deleted the creator from the context
    if (!$context->param( 'creator' )) {
        $context->param( 'creator' => $creator );
    }
    $workflow->attrib({ creator => $context->param( 'creator' ) });

    if ($wf_uiinfo) {
        return $self->__get_workflow_ui_info({ WORKFLOW => $workflow });
    } else {
        return __get_workflow_info($workflow);
    }

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


=head2 get_workflow_instance_types

Load a list of workflow types present in the database for the current realm
and add label and description from the configuration. 

Return value is a hash with the type name as key and a hashref 
with label/description as value.
 
=cut

sub get_workflow_instance_types {
    
    my $self  = shift;
    my $args  = shift;
    
    my $cfg = CTX('config');
    my $pki_realm = CTX('session')->get_pki_realm();    
    
    my $db_results = CTX('dbi_backend')->select(
        TABLE   => [ 'WORKFLOW' ],
        DISTINCT => 1,
        COLUMNS => [ 'WORKFLOW.WORKFLOW_TYPE' ],
        JOIN => [['WORKFLOW_ID']],        
        DYNAMIC => { 'WORKFLOW.PKI_REALM' => $pki_realm }
    );
    
    my $result = {};
    while (my $line = shift @{$db_results}) {
        my $type = $line->{'WORKFLOW.WORKFLOW_TYPE'}; 
        my $label = $cfg->get([ 'workflow', 'def', $type, 'head', 'label' ]);
        my $desc = $cfg->get([ 'workflow', 'def', $type, 'head', 'description' ]);        
        $result->{$type} = { 
            label => $label || $type,
            description => $desc || $label || '',
        };
    }
       
    return $result;
    
}


sub search_workflow_instances_count {

    my $self     = shift;
    my $arg_ref  = shift;
    
    my $params = $self->__search_workflow_instances( $arg_ref );
    
    $params->{COLUMNS} = [{ COLUMN => 'WORKFLOW.WORKFLOW_SERIAL', AGGREGATE => 'COUNT' }];
    
    my $dbi = CTX('dbi_workflow');
    $dbi->commit();
        
    my $result = $dbi->select( %{$params} );
    
    if (!(defined $result && ref $result eq 'ARRAY' && scalar @{$result} == 1)) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_RESULT_COUNT_NOT_ARRAY',
            params => { 'TYPE' => ref $result, },
        );
    }
    
    ##! 16: 'result: ' . Dumper $result
    return $result->[0]->{'WORKFLOW.WORKFLOW_SERIAL'};
    
}

sub search_workflow_instances {
    
    my $self     = shift;
    my $arg_ref  = shift;
    
    my $param = $self->__search_workflow_instances( $arg_ref );
    
    my $dbi = CTX('dbi_workflow');
    $dbi->commit();
        
    my $result = $dbi->select( %{$param} );
    
    if (!(defined $result && ref $result eq 'ARRAY')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_RESULT_NOT_ARRAY',
            params => { 'TYPE' => ref $result, },
        );
    }    
    
    ##! 16: 'result: ' . Dumper $result
    return $result;
    
}
    
sub __search_workflow_instances {
    
    my $self     = shift;
    my $arg_ref  = shift;
    my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;

    my $realm = CTX('session')->get_pki_realm();

    my @attrib;

    # We want to drop searches in context, so log a deprecation warning if context is used
    if ($arg_ref->{CONTEXT} && ref $arg_ref->{CONTEXT} eq 'ARRAY') {
        CTX('log')->log(
            MESSAGE  => "workflow search using context - please fix",
            PRIORITY => 'warn',
            FACILITY => 'application',
        );
        @attrib = @{ $arg_ref->{CONTEXT} };
    }

    if ($arg_ref->{ATTRIBUTE} && ref $arg_ref->{ATTRIBUTE} eq 'ARRAY') {
        @attrib = @{ $arg_ref->{ATTRIBUTE} };
    }

    my $dynamic;
    my @tables;
    my @joins;
    
    
    # Search for known serials, used e.g. for certificate relations
    if ($arg_ref->{SERIAL} && ref $arg_ref->{SERIAL} eq 'ARRAY') {
        $dynamic->{'WORKFLOW.WORKFLOW_SERIAL'} = {VALUE => $arg_ref->{SERIAL}  };
    }
    
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
    foreach my $attrib (@attrib) {
        my $table_alias = 'WORKFLOW_ATTRIBUTES_' . $i;
        my $key   = $attrib->{KEY};
        my $value = $attrib->{VALUE};
        my $operator = 'EQUAL';
        $operator = $attrib->{OPERATOR} if($attrib->{OPERATOR});
        $dynamic->{$table_alias . '.ATTRIBUTE_KEY'}   = {VALUE => $key};
        $dynamic->{$table_alias . '.ATTRIBUTE_VALUE'} = {VALUE => $value, OPERATOR  => $operator };
        push @tables, [ 'WORKFLOW_ATTRIBUTES' => $table_alias ];
        push @joins, 'WORKFLOW_SERIAL';
        $i++;
    }
    push @tables, 'WORKFLOW';
    push @joins, 'WORKFLOW_SERIAL';
    $dynamic->{'WORKFLOW.PKI_REALM'} = {VALUE => $realm};

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
        $dynamic->{'WORKFLOW.WORKFLOW_TYPE'} = {VALUE => $arg_ref->{TYPE}};
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
        $dynamic->{'WORKFLOW.WORKFLOW_STATE'} = {VALUE => $arg_ref->{STATE}};
    }
    
    if (defined $arg_ref->{PROC_STATE}) {
        $dynamic->{'WORKFLOW.WORKFLOW_PROC_STATE'} = { VALUE => $arg_ref->{PROC_STATE} };
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
    
    # Custom ordering
    my $order = 'WORKFLOW.WORKFLOW_SERIAL'; 
    if ($arg_ref->{ORDER}) {
       $order = $arg_ref->{ORDER}; 
    }
    
    my $reverse = 1;
    if (defined $arg_ref->{REVERSE}) {
       $reverse = $arg_ref->{REVERSE};
    }

    ##! 16: 'dynamic: ' . Dumper $dynamic
    ##! 16: 'tables: ' . Dumper(\@tables)
    my %params = (
        TABLE   => \@tables,
        COLUMNS  => [
            'WORKFLOW.WORKFLOW_LAST_UPDATE',
            'WORKFLOW.WORKFLOW_SERIAL',
            'WORKFLOW.WORKFLOW_TYPE',
            'WORKFLOW.WORKFLOW_STATE',
            'WORKFLOW.WORKFLOW_PROC_STATE',
            'WORKFLOW.WORKFLOW_WAKEUP_AT'
        ],
        JOIN     => [ \@joins, ],
        REVERSE  => $reverse,
        DYNAMIC  => $dynamic,
        DISTINCT => 1,
        ORDER => [ $order ],
        %limit,
    );
    ##! 32: 'params: ' . Dumper \%params    
    return \%params;
}

###########################################################################
# private functions

sub __get_workflow_factory {
    ##! 1: 'start'

    my $arg_ref = shift;

    # No Workflow - just get the standard factory
    if (!$arg_ref->{WORKFLOW_ID}) {
        ##! 16: 'No workflow id - create factory from session info'
        return CTX('workflow_factory')->get_factory();
    }

    # Fetch the serialized session from the workflow table
    ##! 16: 'determine factory for workflow ' . $arg_ref->{WORKFLOW_ID}
    my $wf = CTX('dbi_workflow')->first(
        TABLE   => 'WORKFLOW',
        KEY => $arg_ref->{WORKFLOW_ID}
    );
    if (! defined $wf) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_API_GET_WORKFLOW_FACTORY_UNABLE_TO_LOAD_WORKFLOW_INFO',
            params  => {
                WORKFLOW_ID => $arg_ref->{WORKFLOW_ID},
            },
        );
    }

    # We can not load workflows from other realms as this will break config and security
    # The watchdog switches the session realm before instantiating a new factory
    if (CTX('session')->get_pki_realm() ne $wf->{PKI_REALM}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_API_GET_WORKFLOW_FACTORY_REALM_MISSMATCH',
            params  => {
                WORKFLOW_ID => $arg_ref->{WORKFLOW_ID},
                WORKFLOW_REALM => $wf->{PKI_REALM},
                SESSION_REALM => CTX('session')->get_pki_realm()
            },
        );
    }

    my $wf_session_info = CTX('session')->parse_serialized_info($wf->{WORKFLOW_SESSION});
    if (!$wf_session_info || ref $wf_session_info ne 'HASH') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_API_GET_WORKFLOW_FACTORY_UNABLE_TO_PARSE_WORKFLOW_INFO',
            params  => {
                WORKFLOW_ID => $arg_ref->{WORKFLOW_ID},
                WORKFLOW_SESSION => $wf->{WORKFLOW_SESSION}
            },
        );
    }


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

    my $factory = CTX('workflow_factory')->get_factory({ });

    ##! 64: 'factory: ' . Dumper $factory
    if (! defined $factory) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_WORKFLOW_FACTORY_FACTORY_NOT_DEFINED',
        );
    }

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
        PROC_STATE  => $workflow->proc_state(),
        COUNT_TRY  => $workflow->count_try(),
        WAKE_UP_AT  => $workflow->wakeup_at(),
        REAP_AT  => $workflow->reap_at(),
        ATTRIBUTE => $workflow->attrib(),
        CONTEXT => {
        %{$workflow->context()->param()}
        },
    },
    };

    # this stuff seems to be unused and does not reflect the attributes
    # invented for the new ui stuff
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

# validate the parameters given against the field spec of the current activity
# uses positional params: workflow, activity, params
# for now, we do NOT check on types or even requirement to not breal old stuff
# TODO - implement check for type and requirement (perhaps using a validator
# and db transations would be the best way)
sub __validate_input_param {

    my $self = shift;
    my $workflow = shift;
    my $wf_activity = shift;
    my $wf_params   = shift || {};

    ##! 2: "check parameters"
    if (!defined $wf_params || scalar keys %{ $wf_params } == 0) {
        return undef;
    }

    my %fields = ();
    foreach my $field ($workflow->get_action_fields($wf_activity)) {
        $fields{$field->name()} = 1;
    }

    # throw exception on fields not listed in the field spec
    # todo - perhaps build a filter from the spec and tolerate additonal params

    my $result;
    foreach my $key (keys %{$wf_params}) {
        if (not exists $fields{$key}) {
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_API_EXECUTE_WORKFLOW_ACTIVITY_ILLEGAL_PARAM",
                params => {
                    WORKFLOW => $workflow->type(),
                    ID       => $workflow->id(),
                    ACTIVITY => $wf_activity,
                    PARAM    => $key,
                    VALUE    => $wf_params->{$key}
                },
                log => {
                    logger => CTX('log'),
                    priority => 'error',
                    facility => 'workflow',
                },
            );
        }
        $result->{$key} = $wf_params->{$key};
    }

    return $result;
}

sub __execute_workflow_activity {

    my $self = shift;
    my $workflow = shift;
    my $wf_activity = shift;

    ##! 64: Dumper $workflow
    eval {

        # This is a hack to handle simple "autorun" actions which we use to
        # create a bypass around optional actions

        do {
            my $last_state = $workflow->state();
            $workflow->execute_action($wf_activity);

            my @action = $workflow->get_current_actions();
            # A single possible action with a name starting with global_skip indicates
            # that we need the auto execute feature, the second part will (hopefully)
            # prevent infinite loops in case something goes wrong when running execute
            if (scalar @action == 1 && $action[0] =~ m{ \A global_skip }xs) {
                if ($last_state eq $workflow->state() && $wf_activity eq $action[0]) {
                    OpenXPKI::Exception->throw (
                        message  => "I18N_OPENXPKI_SERVER_API_EXECUTE_WORKFLOW_ACTIVITY_AUTO_BYPASS_FOUND_LOOP",
                        params   => {
                            STATE => $last_state, ACTION => $wf_activity, ID => $workflow->id(), TYPE => $workflow->type()
                        }
                    );
                }
                $wf_activity = $action[0];
                CTX('log')->log(
                    MESSAGE  => sprintf ("Found internal bypass action, leave state %s in workflow id %01d (type %s)",
                        $workflow->state(), $workflow->id(), $workflow->type()),
                    PRIORITY => 'info',
                    FACILITY => 'workflow',
                );
            } else {
                $wf_activity = '';
            }
        } while( $wf_activity );
    };
    if ($EVAL_ERROR) {
        my $eval = $EVAL_ERROR;
        CTX('log')->log(
            MESSAGE  => sprintf ("Error executing workflow activity '%s' on workflow id %01d (type %s): %s",
                $wf_activity, $workflow->id(), $workflow->type(), $eval),
            PRIORITY => 'error',
            FACILITY => 'workflow',
        );

        my $log = {
            logger => CTX('log'),
            priority => 'error',
            facility => 'workflow',
        };
  
        ## normal OpenXPKI exception
        $eval->rethrow() if (ref $eval eq "OpenXPKI::Exception");

        ## workflow exception
        my $error = $workflow->context->param('__error');
        if (defined $error)
        {
            if (ref $error eq '') {
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

    return 1;
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


=head2 __get_workflow_factory

Get a suitable factory from handler. If a workflow id is given, the config
version and realm are extracted from the workflow system.

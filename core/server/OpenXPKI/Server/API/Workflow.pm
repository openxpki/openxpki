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
        PKI_REALM  => {VALUE => CTX('session')->get_pki_realm()},
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
        PKI_REALM  => {VALUE => CTX('session')->get_pki_realm()},
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
                "$workflow_table.WORKFLOW_TYPE" => {VALUE => $arg_ref->{'WORKFLOW_TYPE'}},
                "$workflow_table.PKI_REALM"     => {VALUE => CTX('session')->get_pki_realm()},
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
    TABLE    => $workflow_table,
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

    ## NOTE - This breaks the API a bit, the "old" code passed id and type
    ## to load a workflow which is no longer necessary. The attribute "WORKFLOW"
    ## was used as workflow name, we now use it as workflow object!
    ## The order ensures that calls with the old parameters are handled
    ## After finally removing mason we can remove the old code branch

    # All new call set UIINFO
    if ($args->{UIINFO}) {

        return $self->__get_workflow_ui_info( $args );

    } else {
        my $workflow = CTX('workflow_factory')->get_workflow({ ID => $args->{ID}} );
        return __get_workflow_info($workflow);
    }
}


=head2 get_workflow_ui_info

Return a hash with the information taken from the workflow engine plus
additional information taken from the workflow config via connector.
Expects one of:

=item ID numeric workflow id

=item TYPE workflow type

=item WORKFLOW workflow object

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
    $result->{STATE} = CTX('config')->get_hash([ 'workflow', 'def', $result->{WORKFLOW}->{TYPE}, 'state', $result->{WORKFLOW}->{STATE} ]);
    delete $result->{STATE}->{action};

    # Add the possible options (=activity names) in the right order
    my @options = CTX('config')->get_scalar_as_list([ 'workflow', 'def', $result->{WORKFLOW}->{TYPE},  'state', $result->{WORKFLOW}->{STATE}, 'action' ]);

    # Check defined actions against possible ones, non global actions are prefixed
    $result->{STATE}->{option} = [];
    foreach my $option (@options) {
        $option =~ m{ \A ((global_)?)([^\s>]+)}xs;
        $option = $3;
        if (!$2) {
            $option = $head->{prefix}.'_'.$option;
        }
        if ($result->{ACTIVITY}->{$option}) {
            push @{$result->{STATE}->{option}}, $option;
        }
    }
    return $result;

}

sub get_workflow_history {
    my $self    = shift;
    my $arg_ref = shift;
    ##! 1: 'start'

    my $wf_id   = $arg_ref->{ID};

    my $history = CTX('dbi_workflow')->select(
        TABLE => $workflow_history_table,
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
    push @tables, $workflow_table;
    push @joins, 'WORKFLOW_SERIAL';
    $dynamic->{$workflow_table . '.PKI_REALM'} = {VALUE => $realm};

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
        $dynamic->{$workflow_table . '.WORKFLOW_TYPE'} = {VALUE => $arg_ref->{TYPE}};
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
        $dynamic->{$workflow_table . '.WORKFLOW_STATE'} = {VALUE => $arg_ref->{STATE}};
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
                         $workflow_table . '.WORKFLOW_PROC_STATE',
                         $workflow_table . '.WORKFLOW_WAKEUP_AT'
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
    if (!$wf_session_info || ref $wf_session_info ne 'HASH' || !$wf_session_info->{config_version}) {
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

    my $factory = CTX('workflow_factory')->get_factory({
        VERSION => $wf_session_info->{config_version},
        FALLBACK => 1
    });

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
        $workflow->execute_action($wf_activity);
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

        # FIXME TODO STUPID FIXME TODO STUPID FIXME TODO STUPID FIXME TODO STUPID
        # The old ui validates requests by probing them against the create method
        # and ignores the missing field error by string parsing
        # we therefore need to keep that behaviour until decomissioning the old UI
        # The string is from in Workflow::Validator::HasRequiredField
        if (index ($eval , "The following fields require a value:") > -1) {
            ## missing field(s) in workflow
            $eval =~ s/^.*://;
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_API_WORKFLOW_MISSING_REQUIRED_FIELDS",
                params  => {FIELDS => $eval}
            );
        }

        ## This MUST be after the compat block as our workflow  class
        ## transforms any errors into OXI Exceptions now! (breaks mason otherwise)

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

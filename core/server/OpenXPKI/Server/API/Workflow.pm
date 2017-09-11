## OpenXPKI::Server::API::Workflow.pm
##
## Written 2005 by Michael Bell and Martin Bartosch for the OpenXPKI project
## Copyright (C) 2005-2006 by The OpenXPKI Project

package OpenXPKI::Server::API::Workflow;
use strict;
use warnings;
use utf8;

# Core modules
use English;
use Data::Dumper;

# CPAN modules
use Class::Std;
use Workflow::Factory;
use Log::Log4perl::MDC;
use Log::Log4perl::Level;
use Try::Tiny;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Database::Legacy;
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
    my ($self) = @_;
    ##! 1: "list_workflow_titles"
    return CTX('workflow_factory')->get_factory->list_workflow_titles;
}

sub get_workflow_type_for_id {
    my ($self, $args) = @_;

    my $id      = $args->{ID};
    ##! 1: 'start'
    ##! 16: 'id: ' . $id

    my $db_result = CTX('dbi')->select_one(
        from => 'workflow',
        columns => [ 'workflow_type' ],
        where => { workflow_id => $id },
    )
    or OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_WORKFLOW_TYPE_FOR_ID_NO_RESULT_FOR_ID',
        params  => { ID => $id },
    );
    my $type = $db_result->{workflow_type};
    ##! 16: 'type: ' . $type
    return $type;
}


=head2 get_workflow_log

Return the workflow log for a given workflow id (ID), by default you get
the last 50 items of the log sorted neweset first. Set LIMIT to the number
of lines expected or 0 to get all lines (might be huge!). Set REVERSE = 1
to reverse sorting (oldest first).

The return value is a list of arrays with a fixed order of fields:
TIMESTAMP, PRIORITY, MESSAGE

=over

=item ID numeric workflow id

=item LIMIT number of lines to return, 0 for all

=item REVERSE set to 1 to reverse sorting

=back

=cut

sub get_workflow_log {
    my ($self, $args)  = @_;

    ##! 1: "get_workflow_log"
    my $wf_id = $args->{ID};

    # ACL check
    my $wf_type = CTX('api')->get_workflow_type_for_id({ ID => $wf_id });

    my $role = CTX('session')->data->role || 'Anonymous';
    my $allowed = CTX('config')->get([ 'workflow', 'def', $wf_type, 'acl', $role, 'techlog' ] );

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_UI_UNAUTHORIZED_ACCESS_TO_WORKFLOW_LOG',
        params  => {
            'ID' => $wf_id,
            'TYPE' => $wf_type,
            'USER' => CTX('session')->data->user,
            'ROLE' => $role
        },
    ) unless $allowed;

    # Reverse is inverted as we want to have reversed order by default
    my $order = $args->{REVERSE} ? 'ASC' : 'DESC';

    my $sth = CTX('dbi')->select(
        from => 'application_log',
        columns => [ qw( logtimestamp priority message ) ],
        where => { workflow_id => $wf_id },
        order_by => [ "logtimestamp $order", "application_log_id $order" ],
        limit => $args->{LIMIT} // 50,
    );

    my @log;
    while (my $entry = $sth->fetchrow_hashref) {
        # remove the package and session info from the message
        $entry->{message} =~ s/\A\[OpenXPKI::.*\]//;
        push @log, [
            $entry->{logtimestamp},
            Log::Log4perl::Level::to_level($entry->{priority}),
            $entry->{message}
        ];
    }

    return \@log;
}


=head2 get_workflow_info

This is a simple passthru to __get_workflow_ui_info

=cut

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

You can pass certain flags to turn on/off components in the returned hash:

=over

=item ATTRIBUTE

Boolean, set to get the extra attributes.

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

        if (!$factory->authorize_workflow({ ACTION => 'create', TYPE => $args->{TYPE} })) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_GET_WORKFLOW_INFO_NOT_AUTHORIZED',
                params => { ARGS => $args }
            );
        }

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
            LAST_UPDATE => $workflow->last_update()->iso8601(),
            PROC_STATE  => $workflow->proc_state(),
            COUNT_TRY   => $workflow->count_try(),
            WAKE_UP_AT  => $workflow->wakeup_at(),
            REAP_AT     => $workflow->reap_at(),
            CONTEXT     => { %{$workflow->context()->param() } },
        };

        if ($args->{ATTRIBUTE}) {
            $result->{WORKFLOW}->{ATTRIBUTE} = $workflow->attrib();
        }

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
    my ($self, $args) = @_;
    ##! 1: 'start'

    my $wf_id = $args->{ID};
    my $noacl = $args->{NOACL};

    if (!$noacl) {
        my $role = CTX('session')->data->role || 'Anonymous';
        my $wf_type = CTX('api')->get_workflow_type_for_id({ ID => $wf_id });
        my $allowed = CTX('config')->get([ 'workflow', 'def', $wf_type, 'acl', $role, 'history' ] );

        if (!$allowed) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_UI_UNAUTHORIZED_ACCESS_TO_WORKFLOW_HISTORY',
                params  => {
                    'ID' => $wf_id,
                    'TYPE' => $wf_type,
                    'USER' => CTX('session')->data->user,
                    'ROLE' => $role
                },
            );
        }
    }

    my $history = CTX('dbi')->select(
        from => 'workflow_history',
        columns => [ '*' ],
        where => { workflow_id => $wf_id },
        order_by => [ 'workflow_history_date', 'workflow_hist_id' ],
    )->fetchall_arrayref({});

    # TODO #legacydb get_workflow_history() returns HashRef with old DB layer's keys
    my $history_legacy = [
        map {
            {
                WORKFLOW_HISTORY_SERIAL => $_->{workflow_hist_id},
                WORKFLOW_SERIAL         => $_->{workflow_id},
                WORKFLOW_ACTION         => $_->{workflow_action},
                WORKFLOW_DESCRIPTION    => $_->{workflow_description},
                WORKFLOW_STATE          => $_->{workflow_state},
                WORKFLOW_USER           => $_->{workflow_user},
                WORKFLOW_HISTORY_DATE   => $_->{workflow_history_date},
            }
        }
        @$history
    ];

    ##! 64: 'history: ' . Dumper $history
    return $history_legacy;
}

=head2 get_workflow_creator

Returns the name of the workflow creator as given in the attributes table.
This method does NOT use the factory and therefore does not check the acl
rules or matching realm.

=cut

sub get_workflow_creator {
    my ($self, $args) = @_;

    my $result = CTX('dbi')->select_one(
        from => 'workflow_attributes',
        columns => [ 'attribute_value' ],
        where => { 'attribute_contentkey' => 'creator', 'workflow_id' => $args->{ID} },
    );

    return "" unless $result;
    return $result->{attribute_value};

}

=head2 execute_workflow_activity

Execute a given action on a workflow, arguments are passed as hash

=over

=item ID

The workflow id

=item ACTIVITY

The name of the action to execute

=item PARAMS

hash with the params to be passed to the action

=item UIIINFO

boolean, the method will return the full uinfo hash if set and the
workflow state information if not.

=item WORKFLOW

The name of the workflow, optional (read from the tables)

=item ASYNC

B<DO NOT USE THIS FLAG - IT IS NOT FULLY WORKING YET> - see #517

By default, the action is executed inline and the method returns after
all actions are handled. You can detach from the execution by adding
I<ASYNC> as argument: I<fork> will do the fork and return the ui control
structure of the OLD state, I<watch> will fork, wait until the workflow
was started or 15 seconds have elapsed and return the ui structure from
the running workflow.

=back

=cut

sub execute_workflow_activity {
    my ($self, $args) = @_;
    ##! 1: "execute_workflow_activity"

    my $wf_id       = $args->{ID};
    my $wf_type     = $args->{WORKFLOW} // $self->get_workflow_type_for_id({ ID => $wf_id });
    my $wf_activity = $args->{ACTIVITY};
    my $wf_params   = $args->{PARAMS};
    my $wf_uiinfo   = $args->{UIINFO};
    my $fork_mode   = $args->{ASYNC} || '';

    Log::Log4perl::MDC->put('wfid', $wf_id);
    Log::Log4perl::MDC->put('wftype', $wf_type);

    ##! 2: "load workflow"
    my $workflow = $self->__fetch_workflow({ TYPE => $wf_type, ID => $wf_id });

    my $proc_state = $workflow->proc_state();
    # should be prevented by the UI but can happen if workflow moves while UI shows old state
    if ($proc_state ne "manual") {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_EXECUTE_NOT_IN_VALID_STATE',
            params => { ID => $wf_id, PROC_STATE => $proc_state }
        );
    }
    $workflow->reload_observer();

    # check the input params
    my $params = $self->__validate_input_param( $workflow, $wf_activity, $wf_params );
    ##! 16: 'activity params ' . $params

    my $context = $workflow->context();
    $context->param ( $params ) if ($params);

    ##! 64: Dumper $workflow
    if ($fork_mode) {
        $self->__execute_workflow_activity( $workflow, $wf_activity, 1);
        CTX('log')->workflow()->debug("Background execution of workflow activity '$wf_activity' on workflow id $wf_id (type '$wf_type')");

        if ($fork_mode eq 'watch') {
            $workflow = $self->__watch_workflow( $workflow );
        }
    } else {
        $self->__execute_workflow_activity( $workflow, $wf_activity );
        CTX('log')->workflow()->debug("Executed workflow activity '$wf_activity' on workflow id $wf_id (type '$wf_type')");

    }

    return $self->__get_workflow_ui_info({ WORKFLOW => $workflow }) if $wf_uiinfo;
    return $self->__get_workflow_info($workflow);
}

sub fail_workflow {
    my ($self, $args) = @_;
    ##! 1: "fail_workflow"

    my $wf_type  = $args->{WORKFLOW};
    my $wf_id     = $args->{ID};
    my $reason    = $args->{REASON};
    my $error     = $args->{ERROR};

    if (! defined $wf_type) {
        $wf_type = $self->get_workflow_type_for_id({ ID => $wf_id });
    }

    ##! 2: "load workflow"
    my $workflow = $self->__fetch_workflow({ TYPE => $wf_type, ID => $wf_id });

    if (!$error) { $error = 'Failed by user'; }
    if (!$reason) { $reason = 'userfail'; }

    $workflow->set_failed( $error, $reason );

    CTX('log')->workflow()->info("Failed workflow $wf_id (type '$wf_type') with error $error");


    return $self->__get_workflow_ui_info({ WORKFLOW => $workflow });

}

=head2 wakeup_workflow

Only valid if the workflow is in pause state, reads the last action from
the history and reruns it. This method is also used by the watchdog.

=cut
sub wakeup_workflow {
    my ($self, $args) = @_;
    ##! 1: "wakeup workflow"
    return $self->__wakeup_resume_workflow( 'wakeup', $args );
}


=head2 resume_workflow

Only valid if the workflow is in exception state, same as wakeup

=cut
sub resume_workflow {
    my ($self, $args) = @_;
    ##! 1: "resume workflow"
    return $self->__wakeup_resume_workflow( 'resume', $args );
}

=head2 __wakeup_resume_workflow ( mode, args )

Does the work for resume and wakeup, pulls the last action from the history
and executes it.

=over

=item mode

one of I<wakeup> or I<resume>, must match with the current proc state

=item args

Hash holding the workflow information, mandatory key is I<ID>, the
workflow type can be given as I<WORKFLOW> if its known, otherwise
its looked up from the database.

By default, the action is executed inline and the method returns after
all actions are handled. You can detach from the exection by adding
I<ASYNC> as argument: I<fork> will do the fork and return the ui control
structure of the OLD state, I<watch> will fork, wait until the workflow
was started or 15 seconds have elapsed and return the ui structure from
the running workflow.

=back

=cut

sub __wakeup_resume_workflow {
    my ($self, $mode, $args) = @_; # mode: resume or wakeup
    my $fork_mode = $args->{ASYNC} || '';

    if ($mode ne 'wakeup' && $mode ne 'resume') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_WAKEUP_RESUME_WRONG_MODE',
            params => { MODE => $mode }
        );
    }

    my $wf_type  = $args->{WORKFLOW};
    my $wf_id     = $args->{ID};

    if (! defined $wf_type) {
        $wf_type = $self->get_workflow_type_for_id({ ID => $wf_id });
    }

    ##! 2: "load workflow"
    my $workflow = $self->__fetch_workflow({ TYPE => $wf_type, ID => $wf_id });

    ##! 64: 'Got workflow ' . Dumper $workflow

    my $proc_state = $workflow->proc_state();

    # check if the workflow is in the correct proc state to get handled
    if ($mode eq 'wakeup' && $proc_state ne 'pause' && $proc_state ne 'retry_exceeded') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_WAKEUP_NOT_IN_PAUSE',
            params => { ID => $wf_id, PROC_STATE => $workflow->proc_state() }
        );
    } elsif ($mode eq 'resume' && $proc_state ne 'exception') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_WAKEUP_NOT_IN_PAUSE',
            params => { ID => $wf_id, PROC_STATE => $workflow->proc_state() }
        );
    }

    $workflow->reload_observer();

    # pull off the latest action from the history
    my $history = CTX('dbi')->select_one(
        from => 'workflow_history',
        columns => [ 'workflow_action' ],
        where => { 'workflow_id' => $wf_id },
        order_by => [ '-workflow_history_date', '-workflow_hist_id' ]
    );
    my $wf_activity = $history->{workflow_action};

    if ($fork_mode) {
        $mode .= "($fork_mode)";
    }

    CTX('log')->workflow()->info("$mode workflow $wf_id (type '$wf_type') with activity $wf_activity");

    ##! 16: 'execute activity ' . $wf_activity

    if ($fork_mode) {
        $self->__execute_workflow_activity( $workflow, $wf_activity, 1);
        if ($fork_mode eq 'watch') {
            $workflow = $self->__watch_workflow( $workflow );
        }
    } else {
        $self->__execute_workflow_activity( $workflow, $wf_activity );
    }
    return $self->__get_workflow_ui_info({ WORKFLOW => $workflow });
}

sub get_workflow_activities_params {
    my ($self, $args) = @_;
    my @list = ();

    my $wf_type = $args->{WORKFLOW};
    my $wf_id = $args-> {ID};

    my $workflow = $self->__fetch_workflow({ TYPE => $wf_type, ID => $wf_id });

    foreach my $action ( $workflow->get_current_actions() ) {
        my $fields = [];
        foreach my $field ($workflow->get_action_fields( $action ) ) {
            push @{ $fields }, {
                'name'        => $field->name(),
                'label'        => $field->label(),
                'description'    => $field->description(),
                'type'        => $field->type(),
                'requirement'    => $field->requirement(),
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
    my ($self, $args) = @_;
    ##! 1: "create workflow instance"
    ##! 2: Dumper $args

    my $wf_type = $args->{WORKFLOW};
    my $wf_uiinfo = $args->{UIINFO};

    my $workflow = CTX('workflow_factory')->get_factory->create_workflow($wf_type);

    if (! defined $workflow) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_ILLEGAL_WORKFLOW_TITLE",
            params => { WORKFLOW => $wf_type }
        );
    }

    $workflow->reload_observer();

    ## init creator
    my $wf_id = $workflow->id();

    Log::Log4perl::MDC->put('wfid', $wf_id);
    Log::Log4perl::MDC->put('wftype', $wf_type);

    my $context = $workflow->context();
    my $creator = CTX('session')->data->user;
    $context->param( 'creator'  => $creator );
    $context->param( 'creator_role'  => CTX('session')->data->role );

    # This is crucial and must be done before the first execute as otherwise
    # workflow acl fails when the first non-initial action is autorun
    $workflow->attrib({ creator => $creator });

    OpenXPKI::Server::Context::setcontext(
    {
        workflow_id => $wf_id,
        force       => 1,
    });

    ##! 16: 'workflow id ' .  $wf_id
    CTX('log')->workflow()->info("Workflow instance $wf_id created for $creator (type: '$wf_type')");



    # load the first state and check for the initial action
    my $state = undef;

    my @actions = $workflow->get_current_actions();
    if (not scalar @actions || scalar @actions != 1) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_API_CREATE_WORKFLOW_INSTANCE_NO_FIRST_ACTIVITY",
            params => { WORKFLOW => $wf_type }
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
            message => "Failed to create workflow instance!",
            log =>  {
                priority => 'error',
                facility => 'workflow'
            }
        );
    }

    # check back for the creator in the context and copy it to the attribute table
    # doh - somebody deleted the creator from the context
    if (!$context->param( 'creator' )) {
        $context->param( 'creator' => $creator );
    }
    $workflow->attrib({ creator => $context->param( 'creator' ) });

    # TODO - we need to persist the workflow here again!

    Log::Log4perl::MDC->put('wfid', undef);
    Log::Log4perl::MDC->put('wftype', undef);

    return $self->__get_workflow_ui_info({ WORKFLOW => $workflow }) if $wf_uiinfo;
    return $self->__get_workflow_info($workflow);
}

sub get_workflow_activities {
    my ($self, $args) = @_;

    my $wf_type = $args->{WORKFLOW};
    my $wf_id    = $args->{ID};

    my $workflow = $self->__fetch_workflow({ TYPE => $wf_type, ID => $wf_id });
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
    my ($self, $args) = @_;

    my $cfg = CTX('config');
    my $pki_realm = CTX('session')->data->pki_realm;

    my $sth = CTX('dbi')->select(
        from   => 'workflow',
        columns => [ -distinct => 'workflow_type' ],
        where => { pki_realm => $pki_realm },
    );

    my $result = {};
    while (my $line = $sth->fetchrow_hashref) {
        my $type = $line->{workflow_type};
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
    my ($self, $args) = @_;

    my $params = $self->__search_query_params($args);

    # Not usefull and sometimes even dangerous
    foreach my $p (qw(limit offset order_by )) {
        delete $params->{$p} if (defined $params->{$p});
    }

    my $result = CTX('dbi')->select_one(
        %{$params},
        columns => [ 'COUNT(workflow.workflow_id)|amount' ],
    );

    ##! 1: "finished"
    return $result->{amount};
}

sub search_workflow_instances {
    my ($self, $args) = @_;

    my $params = $self->__search_query_params($args);

    my $result = CTX('dbi')->select(
        %{$params},
        columns => [ qw(
            workflow_last_update
            workflow.workflow_id
            workflow_type
            workflow_state
            workflow_proc_state
            workflow_wakeup_at
            pki_realm
        ) ],
    )->fetchall_arrayref({});

    my $result_legacy = [ map { OpenXPKI::Server::Database::Legacy->workflow_to_legacy($_, 1) } @$result ];

    ##! 16: 'result: ' . Dumper $result_legacy
    return $result_legacy;

}

sub __search_query_params {
    my ($self, $args) = @_;

    my $re_alpha_string      = qr{ \A [ \w \- \. : \s ]* \z }xms;

    my $where = {};
    my $params = {
        where => $where,
    };

    # Search for known serials, used e.g. for certificate relations
    if ($args->{SERIAL} && ref $args->{SERIAL} eq 'ARRAY') {
        $where->{'workflow.workflow_id'} = $args->{SERIAL};
    }

    # we need to join over the workflow_attributes table
    my @attr_cond;
    if ($args->{ATTRIBUTE} && ref $args->{ATTRIBUTE} eq 'ARRAY') {
        @attr_cond = @{ $args->{ATTRIBUTE} };
    }
    my @join_spec = ();
    my $ii = 0;
    for my $cond (@attr_cond) {
        ##! 16: 'certificate attribute: ' . Dumper $cond
        my $table_alias = "workflowattr$ii";

        # add join table
        push @join_spec, ( 'workflow.workflow_id=workflow_id', "workflow_attributes|$table_alias" );

        # add search constraint
        $where->{ "$table_alias.attribute_contentkey" } = $cond->{KEY};

        $cond->{OPERATOR} //= 'EQUAL';
        # sanitize wildcards (don't overdo it...)
        if ($cond->{OPERATOR} eq 'LIKE') {
            $cond->{VALUE} =~ s/\*/%/g;
            $cond->{VALUE} =~ s/%%+/%/g;
        }
        # TODO #legacydb search_workflow_instances' ATTRIBUTE allows old DB layer syntax
        $where->{ "$table_alias.attribute_value" } =
            OpenXPKI::Server::Database::Legacy->convert_dynamic_cond($cond);

        $ii++;
    }

    if (scalar @join_spec) {
        $params->{from_join} = join " ", 'workflow', @join_spec;
    }
    else {
        $params->{from} = 'workflow',
    }

    # Do not restrict if PKI_REALM => "_any"
    if (not $args->{PKI_REALM} or $args->{PKI_REALM} !~ /_any/i) {
        $where->{pki_realm} = $args->{PKI_REALM} // CTX('session')->data->pki_realm;
    }

    if (defined $args->{TYPE}) {
        # do parameter validation (here instead of the API because the API can
        # ensure it's an Scalar or ArrayRef but can't do regex checks on it
        my @types = ref $args->{TYPE} ? @{ $args->{TYPE} } : ($args->{TYPE});
        for my $type (@types) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_TYPE_NOT_ALPHANUMERIC',
                params  => { TYPE => $type },
            ) unless $type =~ $re_alpha_string;
        }
        $where->{workflow_type} = $args->{TYPE};
    }

    if (defined $args->{STATE}) {
        my @states = ref $args->{STATE} ? @{ $args->{STATE} } : ($args->{STATE});
        for my $state (@states) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_SEARCH_WORKFLOW_INSTANCES_STATE_NOT_ALPHANUMERIC',
                params  => { STATE => $state },
            ) unless $state =~ $re_alpha_string;
        }
        $where->{workflow_state} = $args->{STATE};
    }

    $where->{workflow_proc_state} = $args->{PROC_STATE} if defined $args->{PROC_STATE};

    if ( defined $args->{LIMIT} ) {
        $params->{limit} = $args->{LIMIT};
        $params->{offset} = $args->{START} if $args->{START};
    }

    # Custom ordering
    my $desc = "-"; # not set or 0 means: DESCENDING, i.e. "-"
    $desc = "" if defined $args->{REVERSE} and $args->{REVERSE} == 0;
    # TODO #legacydb Code that removes table name prefix
    if (!$args->{ORDER} || $args->{ORDER} =~ /WORKFLOW_SERIAL/) {
        $args->{ORDER} = 'workflow_id';
    } else {
        $args->{ORDER} =~ s/^WORKFLOW\.//;
    }
    $params->{order_by} = sprintf "%s%s", $desc, $args->{ORDER};

    ##! 32: 'params: ' . Dumper $params
    return $params;
}

###########################################################################
# private functions

# Returns an instance of OpenXPKI::Server::Workflow
sub __fetch_workflow {
    my ($self, $args) = @_;

    my $wf_id = $args->{ID};
    my $factory = $args->{FACTORY} || CTX('workflow_factory')->get_factory;

    #
    # Check workflow PKI realm and set type (if not given)
    #
    my $dbresult = CTX('dbi')->select_one(
        from => 'workflow',
        columns => [ qw( workflow_type pki_realm ) ],
        where => { workflow_id => $wf_id },
    )
    or OpenXPKI::Exception->throw(
        message => 'Requested workflow not found',
        params  => { WORKFLOW_ID => $wf_id },
    );

    my $wf_type = $args->{TYPE} // $dbresult->{workflow_type};

    # We can not load workflows from other realms as this will break config and security
    # The watchdog switches the session realm before instantiating a new factory
    if (CTX('session')->data->pki_realm ne $dbresult->{pki_realm}) {
        OpenXPKI::Exception->throw(
            message => 'Requested workflow is not in current PKI realm',
            params  => {
                WORKFLOW_ID => $wf_id,
                WORKFLOW_REALM => $dbresult->{pki_realm},
                SESSION_REALM => CTX('session')->data->pki_realm,
            },
        );
    }

    #
    # Fetch workflow via Workflow engine
    #
    my $workflow = $factory->fetch_workflow($wf_type, $wf_id);

    OpenXPKI::Server::Context::setcontext({
        workflow_id => $wf_id,
        force       => 1,
    });

    return $workflow;
}

sub __get_workflow_info {
    my ($self, $workflow) = @_;

    ##! 1: "__get_workflow_info"

    ##! 64: Dumper $workflow

    my $result = {
    WORKFLOW => {
        ID          => $workflow->id(),
        STATE       => $workflow->state(),
        TYPE        => $workflow->type(),
        DESCRIPTION => $workflow->description(),
        LAST_UPDATE => $workflow->last_update()->iso8601(),
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
                    priority => 'error',
                    facility => 'workflow',
                },
            );
        }
        $result->{$key} = $wf_params->{$key};
    }

    return $result;
}

=head2 __execute_workflow_activity( workflow, activity, fork )

Execute the named activity on the given workflow object. Returns
0 on success and throws exceptions on errors.

B<DO NOT USE THIS FLAG - IT IS NOT FULLY WORKING YET> - see #517
The third argument is an optional boolean flag weather to executed
the activity in the background. If used, the return value is the PID
of the forked child.

=cut

sub __execute_workflow_activity {
    my $self = shift;
    my $workflow = shift;
    my $wf_activity = shift;
    my $run_async = shift || '';

    my $log = CTX('log')->workflow;

    my $activity = sub {
        ##! 8: 'execute activity ' . $wf_activity

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
                $log->info(sprintf ("Found internal bypass action, leave state %s in workflow id %01d (type %s)",
                    $workflow->state(), $workflow->id(), $workflow->type()));

            } else {
                $wf_activity = '';
            }
        } while( $wf_activity );
    };


    #
    # ASYNCHRONOUS - fork
    #
    if ($run_async) {
        $log->info(sprintf ("Workflow called with fork mode set! State %s in workflow id %01d (type %s)",
            $workflow->state(), $workflow->id(), $workflow->type()));

        # FORK
        my $pid = OpenXPKI::Daemonize->new->fork_child; # parent returns PID, child returns 0

        # parent process
        if ($pid > 0) {
            ##! 32: ' Workflow instance succesfully forked with pid ' . $pid
            $log->trace("Forked workflow instance with PID $pid") if $log->is_trace;
            return $pid;
        }

        # child process
        try {
            ##! 16: ' Workflow instance succesfully forked - I am the workflow'
            # append fork info to process name
            OpenXPKI::Server::__set_process_name("workflow: id %d (detached)", $workflow->id());

            # create memory-only session for workflow if it's not already one
            if (CTX('session')->type ne 'Memory') {
                my $session = OpenXPKI::Server::Session->new(type => "Memory")->create;
                $session->data->user( CTX('session')->data->user );
                $session->data->role( CTX('session')->data->role );
                $session->data->pki_realm( CTX('session')->data->pki_realm );

                OpenXPKI::Server::Context::setcontext({ session => $session, force => 1 });
                Log::Log4perl::MDC->put('sid', substr(CTX('session')->id,0,4));
            }

            # run activity
            $activity->();

            # DB commits are done inside the workflow engine
        }
        catch {
            # DB rollback is not needed as this process will terminate now anyway
            local $@ = $_; # makes OpenXPKI::Exception compatible with Try::Tiny
            if (my $exc = OpenXPKI::Exception->caught) {
                $exc->show_trace(1);
            }
            # make sure the cleanup code does not die as this would escape this method
            eval { CTX('log')->system->error($_) };
        };

        eval { CTX('dbi')->disconnect };

        ##! 16: 'Backgrounded workflow finished - exit child'
        exit;
    }

    #
    # SYNCHRONOUS
    #

    ##! 64: Dumper $workflow
    OpenXPKI::Server::__set_process_name("workflow: id %d", $workflow->id());
    # run activity
    eval { $activity->() };

    if (my $eval_err = $EVAL_ERROR) {
       $log->error(sprintf ("Error executing workflow activity '%s' on workflow id %01d (type %s): %s",
            $wf_activity, $workflow->id(), $workflow->type(), $eval_err));

        OpenXPKI::Server::__set_process_name("workflow: id %d (exception)", $workflow->id());

        my $logcfg = { priority => 'error', facility => 'workflow' };

        # clear MDC
        Log::Log4perl::MDC->put('wfid', undef);
        Log::Log4perl::MDC->put('wftype', undef);

        ## normal OpenXPKI exception
        $eval_err->rethrow() if (ref $eval_err eq "OpenXPKI::Exception");

        ## workflow exception
        my $error = $workflow->context->param('__error');
        if (defined $error) {
            if (ref $error eq '') {
                OpenXPKI::Exception->throw (
                    message => $error,
                    log     => $logcfg,
                );
            }
            if (ref $error eq 'ARRAY') {
                my @list = ();
                for my $item (@{$error}) {
                    eval {
                        OpenXPKI::Exception->throw(
                            message => $item->[0],
                            params  => $item->[1]
                        );
                    };
                    push @list, $EVAL_ERROR;
                }
                OpenXPKI::Exception->throw (
                    message  => "I18N_OPENXPKI_SERVER_API_EXECUTE_WORKFLOW_ACTIVITY_FAILED",
                    children => [ @list ],
                    log      => $logcfg,
                );
            }
        }

        ## unknown exception
        OpenXPKI::Exception->throw(
            message => "$eval_err", # stringify bubble up exceptions
            log     => $logcfg,
        );
    };

    OpenXPKI::Server::__set_process_name("workflow: id %d (cleanup)", $workflow->id());
    return 0;
}

=head2 __watch_workflow ( workflow, duration = 15, sleep = 2 )

Watch a workflow for changes based on the last_update column.
Expects the workflow object as first parameter, the duration to watch
and the sleep interval between the checks can be passed as second and
third parameters, default is 15s/2s.

The method returns the changed workflow object if a change was detected
or the initial workflow object if no change happend.

=cut
sub __watch_workflow {

    my $self = shift;
    my $workflow = shift;
    my $duration= shift || 15;
    my $sleep = shift || 2;

    # we poll the workflow table and watch if the update timestamp changed
    my $old_time = $workflow->last_update->strftime("%Y-%m-%d %H:%M:%S");
    my $timeout = time() + $duration;
    ##! 32:' Fork mode watch - timeout - '.$timeout.' - last update ' . $old_time

    do {
        my $workflow_state = CTX('dbi')->select_one(
            from => 'workflow',
            columns => [ 'workflow_last_update' ],
            where => { 'workflow_id' => $workflow->id() },
        );
        ##! 64: 'Wfl update is ' . $workflow_state->{workflow_last_update}
        if ($workflow_state->{workflow_last_update} ne $old_time) {
            ##! 8: 'Refetch workflow'
            # refetch the workflow to get the updates
            my $factory = $workflow->factory();
            $workflow = $factory->fetch_workflow( $workflow->type(), $workflow->id() );
            $timeout = 0;
        } else {
            ##! 64: 'sleep'
            sleep 2;
        }
    } while (time() < $timeout);

    return $workflow;
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

=item * ATTRIBUTE

The named parameter ATTRIBUTE must be a hash reference.
Apply search filter to search using the KEY/VALUE pair passed in
ATTRIBUTE and match all Workflow instances whose attributes contain all
of the specified tuples.
It is possible to use SQL wildcards such as % in the VALUE field.

Examples:

    my @workflow_ids = $api->search_workflow_instances( {
        ATTRIBUTE => {
            KEY   => 'SCEP_TID',
            VALUE => 'ECB001D912E2A357E6E813D87A72E641',
        }
    } );

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

Returns a HashRef:

    {
        'WORKFLOW.PKI_REALM'            => 'alpha',
        'WORKFLOW.WORKFLOW_TYPE'        => 'wf_type_1',
        'WORKFLOW.WORKFLOW_SERIAL'      => 511,
        'WORKFLOW.WORKFLOW_PROC_STATE'  => 'manual',
        'WORKFLOW.WORKFLOW_STATE'       => 'PERSIST',
        'WORKFLOW.WORKFLOW_LAST_UPDATE' => '2017-04-07 23:10:05',
        'WORKFLOW.WORKFLOW_WAKEUP_AT'   => 0,
    }

=head2 search_workflow_instances_count

Works exactly the same as search_workflow_instances, but returns the
number of results instead of the results themselves.


=head2 __fetch_workflow

Fetch a workflow from the workflow factory. Throws an exception if the
workflow's PKI realm is different from the current one.

B<Parameters>

=over

=item * ID

Workflow identifier.

=item * TYPE (optional)

Workflow type. Read from database if omitted.

=item * FACTORY (optional)

Workflow factory (instance of L<OpenXPKI::Workflow::Handler>). Can be given to
speed up function call if the factory is already known.

=back

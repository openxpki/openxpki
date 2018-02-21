package OpenXPKI::Server::API2::Plugin::Workflow::Util;
use Moose;

# Core modules
use English;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Connector::WorkflowContext;

=head2 validate_input_params

Validates the given parameters against the field spec of the current activity
and returns

Currently NO check is performed on data types or required fields to not break
old code.

Currently returns the input parameter HashRef on success. Throws an exception
on error.

B<Positional parameters>

=over

=item * C<$workflow> (Str) - workflow type / name

=item * C<$activity> (Str) - workflow activity

=item * C<$params> (HashRef) - parameters to validate

=back

=cut
# TODO - implement check for type and requirement (perhaps using a validator
sub validate_input_params {
    my ($self, $workflow, $activity, $params) = @_;
    $params //= {};

    ##! 2: "check parameters"
    return undef unless scalar keys %{ $params };

    my %fields = map { $_->name => 1 } $workflow->get_action_fields($activity);

    # throw exception on fields not listed in the field spec
    # TODO - perhaps build a filter from the spec and tolerate additonal params
    my $result;
    for my $key (keys %{$params}) {
        if (not exists $fields{$key}) {
            OpenXPKI::Exception->throw (
                message => "Illegal parameter given for workflow activity",
                params => {
                    workflow => $workflow->type,
                    id       => $workflow->id,
                    activity => $activity,
                    param    => $key,
                    value    => $params->{$key}
                },
                log => { priority => 'error', facility => 'workflow' },
            );
        }
        $result->{$key} = $params->{$key};
    }

    return $result;
}

=head2 execute_activity

Executes the named activity on the given workflow object.

Returns 0 on success and throws exceptions on errors.

B<Positional parameters>

=over

=item * C<$workflow> (Str) - workflow type / name

=item * C<$activity> (Str) - workflow activity

=back

=cut
sub execute_activity {
    my ($self, $workflow, $activity) = @_;

    my $log = CTX('log')->workflow;

    ##! 64: Dumper $workflow
    OpenXPKI::Server::__set_process_name("workflow: id %d", $workflow->id());
    # run activity
    eval { $self->_run_activity($workflow, $activity) };

    if (my $eval_err = $EVAL_ERROR) {
       $log->error(sprintf ("Error executing workflow activity '%s' on workflow id %01d (type %s): %s",
            $activity, $workflow->id(), $workflow->type(), $eval_err));

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
                OpenXPKI::Exception->throw(
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
            message => "$eval_err", # stringify bubbled up exceptions
            log     => $logcfg,
        );
    };

    OpenXPKI::Server::__set_process_name("workflow: id %d (cleanup)", $workflow->id());
    return 0;
}

=head2 execute_activity_async

Execute the named activity on the given workflow object ASYNCHRONOUSLY, i.e.
forks off a child process.

Returns the PID of the forked child.

B<Positional parameters>

=over

=item * C<$workflow> (Str) - workflow type / name

=item * C<$activity> (Str) - workflow activity

=back

=cut
sub execute_activity_async {
    my ($self, $workflow, $activity) = @_;

    my $log = CTX('log')->workflow;

    $log->info(sprintf ("Executing workflow activity asynchronously. State %s in workflow id %01d (type %s)",
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
        $self->_run_activity($workflow, $activity);

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

# runs the given workflow activity on the Workflow engine
sub _run_activity {
    my ($self, $wf, $ac) = @_;
    ##! 8: 'execute activity ' . $ac

    my $log = CTX('log')->workflow;

    # This is a hack to handle simple "autorun" actions which we use to
    # create a bypass around optional actions
    do {
        my $last_state = $wf->state;
        $wf->execute_action($ac);

        my @action = $wf->get_current_actions();
        # A single possible action with a name starting with global_skip indicates
        # that we need the auto execute feature, the second part will (hopefully)
        # prevent infinite loops in case something goes wrong when running execute
        $ac = '';
        if (scalar @action == 1 and $action[0] =~ m{ \A global_skip }xs) {
            if ($last_state eq $wf->state && $ac eq $action[0]) {
                OpenXPKI::Exception->throw (
                    message  => "Loop found in auto bypass while executing workflow activity",
                    params   => {
                        state => $last_state, action => $ac, id => $wf->id, type => $wf->type
                    }
                );
            }
            $log->info(sprintf ("Found internal bypass action, leaving state %s in workflow id %01d (type %s)",
                $wf->state, $wf->id, $wf->type));

            $ac = $action[0];
        }
    } while($ac);
}

=head2 get_workflow_ui_info

Returns a I<HashRef> with informations from the workflow engine plus additional
informations taken from the workflow config.

Parameter I<HashRef>:

=over

=item * ID - numeric workflow id

=item * TYPE - workflow type

=item * WORKFLOW - workflow object

=item * ACTIVITY - Only return informations about this workflow action. Default:
all actions available in the current state.

Note: you have to prepend the workflow prefix to the action separated by an
underscore.

=back

You can pass certain flags to turn on/off components in the returned hash:

=over

=item * ATTRIBUTE - Boolean, set to get the extra attributes.

=back

=cut
sub get_workflow_ui_info {
    ##! 1: 'start'
    my ($self, $args) = @_;

    my $factory;
    my $result = {};

    # initial info receives a workflow title
    my ($wf_description, $wf_state);
    my @activities;
    # TODO #spaghetti split into several methods instead of IF ELSE branches
    # (one for search via ID/WORKFLOW and one for TYPE. Move code at bottom to separate method)
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

        $result->{workflow} = {
            type        => $args->{TYPE},
            id          => 0,
            state       => 'INITIAL',
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

        $result->{workflow} = {
            id          => $workflow->id(),
            state       => $workflow->state(),
            type        => $workflow->type(),
            last_update => $workflow->last_update()->iso8601(),
            proc_state  => $workflow->proc_state(),
            count_try   => $workflow->count_try(),
            wake_up_at  => $workflow->wakeup_at(),
            reap_at     => $workflow->reap_at(),
            context     => { %{$workflow->context()->param() } },
        };

        if ($args->{ATTRIBUTE}) {
            $result->{workflow}->{attribute} = $workflow->attrib();
        }

        $result->{handles} = $workflow->get_global_actions();

        ##! 32: 'Workflow result ' . Dumper $result
        if ($args->{ACTIVITY}) {
            @activities = ( $args->{ACTIVITY} );
        } else {
            @activities = $workflow->get_current_actions();
        }
    }

    $result->{activity} = {};

    OpenXPKI::Connector::WorkflowContext::set_context( $result->{WORKFLOW}->{CONTEXT} );
    foreach my $wf_action (@activities) {
        $result->{activity}->{$wf_action} = $factory->get_action_info( $wf_action, $result->{workflow}->{type} );
    }
    OpenXPKI::Connector::WorkflowContext::set_context();

    # Add Workflow UI Info
    my $head = CTX('config')->get_hash([ 'workflow', 'def', $result->{workflow}->{type}, 'head' ]);
    $result->{workflow}->{label} = $head->{label};
    $result->{workflow}->{description} = $head->{description};

    # Add State UI Info
    my $ui_state = CTX('config')->get_hash([ 'workflow', 'def', $result->{workflow}->{type}, 'state', $result->{workflow}->{state} ]);
    my @ui_state_out;
    if ($ui_state->{output}) {
        if (ref $ui_state->{output} eq 'ARRAY') {
            @ui_state_out = @{$ui_state->{output}};
        } else {
            @ui_state_out = CTX('config')->get_list([ 'workflow', 'def', $result->{workflow}->{type}, 'state', $result->{workflow}->{state}, 'output' ]);
        }

        $ui_state->{output} = [];
        foreach my $field (@ui_state_out) {
            # Load the field definitions
            push @{$ui_state->{output}}, $factory->get_field_info($field, $result->{workflow}->{type} );
        }
    }

    # Info for buttons
    $result->{state} = $ui_state;

    my $button = $result->{state}->{button};
    $result->{state}->{button} = {};
    delete $result->{state}->{action};


    # Add the possible options (=activity names) in the right order
    my @options = CTX('config')->get_scalar_as_list([ 'workflow', 'def', $result->{workflow}->{type},  'state', $result->{workflow}->{state}, 'action' ]);

    # Check defined actions against possible ones, non global actions are prefixed
    $result->{state}->{option} = [];

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
        if ($result->{activity}->{$action}) {
            push @{$result->{state}->{option}}, $action;
        }

        # Add button config if available
        $result->{state}->{button}->{$action} = $button->{$option} if ($button->{$option});
    }

    # add button markup (head)
    if ($button->{_head}) {
        $result->{state}->{button}->{_head} = $button->{_head};
    }

    return $result;
}

=head2 get_workflow_info

Return a hash with the informations taken from the workflow engine plus.

B<Positional parameters>:

=over

=item * C<$workflow> I<Workflow> - workflow object


=back

=cut
sub get_workflow_info {
    my ($self, $workflow) = @_;

    ##! 1: "get_workflow_info"

    ##! 64: Dumper $workflow

    my $result = {
        workflow => {
            id          => $workflow->id(),
            state       => $workflow->state(),
            type        => $workflow->type(),
            description => $workflow->description(),
            last_update => $workflow->last_update()->iso8601(),
            proc_state  => $workflow->proc_state(),
            count_try   => $workflow->count_try(),
            wake_up_at  => $workflow->wakeup_at(),
            reap_at     => $workflow->reap_at(),
            attribute   => $workflow->attrib(),
            context     => { %{ $workflow->context->param } },
        },
    };

    # FIXME - this stuff seems to be unused and does not reflect the attributes
    # invented for the new ui stuff
    for my $activity ($workflow->get_current_actions()) {
        ##! 2: $activity

        # FIXME - bug in Workflow::Action (v0.17)?: if no fields are defined the
        # method tries to return an arrayref on an undef'd value
        my @fields;
        eval { @fields = $workflow->get_action_fields($activity) };

        for my $field (@fields) {
            ##! 4: $field->name()
            $result->{activity}->{$activity}->{field}->{$field->name()} = {
                description => $field->description(),
                required    => $field->is_required(),
            };
        }
    }

    return $result;
}

=head2 watch ( workflow, duration = 15, sleep = 2 )

Watch a workflow for changes based on the last_update column.
Expects the workflow object as first parameter, the duration to watch
and the sleep interval between the checks can be passed as second and
third parameters, default is 15s/2s.

The method returns the changed workflow object if a change was detected
or the initial workflow object if no change happend.

=cut
sub watch {
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

# Returns an instance of OpenXPKI::Server::Workflow
sub fetch_workflow {
    my ($self, $type, $id) = @_;

    my $factory = CTX('workflow_factory')->get_factory;

    #
    # Check workflow PKI realm and set type (if not given)
    #
    my $dbresult = CTX('dbi')->select_one(
        from => 'workflow',
        columns => [ qw( workflow_type pki_realm ) ],
        where => { workflow_id => $id },
    )
    or OpenXPKI::Exception->throw(
        message => 'Requested workflow not found',
        params  => { workflow_id => $id },
    );

    my $wf_type = $type // $dbresult->{workflow_type};

    # We can not load workflows from other realms as this will break config and security
    # The watchdog switches the session realm before instantiating a new factory
    if (CTX('session')->data->pki_realm ne $dbresult->{pki_realm}) {
        OpenXPKI::Exception->throw(
            message => 'Requested workflow is not in current PKI realm',
            params  => {
                workflow_id => $id,
                workflow_realm => $dbresult->{pki_realm},
                session_realm => ctx('session')->data->pki_realm,
            },
        );
    }

    #
    # Fetch workflow via Workflow engine
    #
    my $workflow = $factory->fetch_workflow($wf_type, $id);

    OpenXPKI::Server::Context::setcontext({
        workflow_id => $id,
        force       => 1,
    });

    return $workflow;
}

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Workflow::create_workflow_instance;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::create_workflow_instance

=cut
# Core modules
use English;
use Scalar::Util 'blessed';

# Project modules
use OpenXPKI::DateTime;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;
with 'OpenXPKI::Server::API2::TenantRole';

=head1 COMMANDS

=head2 create_workflow_instance

Create a new workflow instance of the given type.

Limitations and requirements:

Each workflow MUST start with a state called I<INITIAL> and MUST have exactly
one action. I<workflow_id> and I<creator> are added to the context as virtual
values - those can not be changed. I<creator> is set to the username of the
current session user, to change this use the SetCreator activity or change
the workflow B<attribute> I<creator> directly!

Workflows that fail to complete the I<INITIAL> action are not saved and can
not be continued.

B<Parameters>

=over

=item * C<workflow> I<Str> - workflow name

=item * C<activity> I<Str> - name of the action to execute

This is only required if the workflow has more than one initial action.

=item * C<params> I<HashRef> - workflow parameters. Optional, default: {}

=item * C<ui_info> I<Bool> - set to 1 to also return detail informations about
the workflow that can be used in the UI

=item * C<norun> I(persist|detach|watchdog) - if set to I<persist>, the initial
context is persisted but the initial action is not run. If set to I<detach>,
the initial workflow including its id is returned and the initial action is
executed in the background (forked process). It set to I<watchdog> the context
is persisted and control is handed over to the watchdog.

=item * C<use_lock> I<HashRef|Str>. Optional, default is {}

Create a datapool item as lock using the given I<namespace> and I<key>
with the workflow id as value. The workflow is not created and an exception
is thrown if a lock with the same key already exists in the namespace.

The lock is commited to the database as soon as the initial action was
executed or if I<norun> is set when the next commit occurs. In the meantime
the database driver holds a row lock which might have a performance impact.
If the workflow crashes during the inital action, the lock will disappear,
if the crash happens after the initial action, the lock will remain and
point to a broken workflow.

You can define the error handling by setting I<on_error> to:

=over

=item die - the default, throw an exception

=item skip - return undef

=item workflow - return the existing workflow, input is discarded

=item force - ignore the lock, create new workflow and overwrite lock

=back

Note that I<force> will not stop or modifiy the existing workflow, so the old
workflow will loose its relation to the lock id!

The namespace has a default of I<workflow.lock>, so if you dont need to
modify neither namespace or error handling you can directly pass the locks
key as String instead of using a HashRef.

=item * C<tenant> L<Tenant|OpenXPKI::Types/Tenant> - tenant. Optional

Assign the new workflow to the given tenant. The value must be a valid
tenant for the current session user, if it is not given and tenant mode
is turned on, the primary tenant is loaded. Set to the emtpy string to
not assign the workflow to any tenant.

=item * C<_run_as_system> I<Bool>. Optional

Execute the workflow with the permissions of the system role, disables
validation or autodiscovery of the tenant.

=back

B<Returns> a I<HashRef> with workflow information, see
L<OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info> for more details.

=cut
command "create_workflow_instance" => {
    workflow => { isa => 'AlphaPunct', required => 1, },
    activity => { isa => 'AlphaPunct' },
    params   => { isa => 'HashRef', default => sub { {} } },
    ui_info  => { isa => 'Bool', default => 0, },
    norun    => { isa => 'Str', matching => qr{ \A(persist|detach|watchdog|)\z }xms, default => '' },
    use_lock => { isa => 'HashRef|Str' },
    tenant   => { isa => 'Tenant' },
    _run_as_system  => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;
    my $type = $params->workflow;

    my $norun = $params->norun;

    ##! 16: 'Norun ' . $norun
    ##! 64: Dumper $params

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    my $workflow;
    my $tenant;
    if ($params->_run_as_system) {

        OpenXPKI::Exception->throw (
            message => '_run_as_system requires norun=detach'
        ) unless($norun eq 'detach');

        $tenant = $params->tenant;
        $workflow = CTX('workflow_factory')->get_factory->create_workflow_as_system($type);

    } else {

        $tenant = $self->get_validated_tenant( $params->tenant );
        $workflow = CTX('workflow_factory')->get_factory->create_workflow($type);
    }
    ##! 32: 'Tenant ' . $tenant//'<undef>'

    OpenXPKI::Exception->throw (
        message => "Could not initialize workflow",
        params => { type => $type }
    ) unless($workflow);

    my $id = $workflow->id;
    ##! 2: "New workflow's ID: $id"

    if (my $lock = $params->use_lock) {
        my $lock_id = $self->_handle_lock($id, $lock);
        # skip was used
        return unless (defined $lock_id);

        # there is already a workflow
        return $util->get_wf_info( id => $lock_id, with_ui_info => $params->ui_info ) if ($lock_id);
    }

    my $last_id = Log::Log4perl::MDC->get('wfid') || undef;
    my $last_type = Log::Log4perl::MDC->get('wftype') || undef;
    Log::Log4perl::MDC->put('wfid',   $id);
    Log::Log4perl::MDC->put('wftype', $type);

    my $context = $workflow->context;
    my $creator = CTX('session')->data->user;

    # workflow_id is a virtual key that is added by the Context on init so
    # it does not exist in the fresh context after creation, fixes #442.
    # We set it directly to prevent triggering any "on update" methods.
    # Only set this on non-volatile workflows (numeric ids).
    $context->{PARAMS}{'workflow_id'} = $id if ($id =~ m{\A\d+\z});

    # same for creator
    $context->{PARAMS}{'creator'} = $creator;

    # This is crucial and must be done before the first execute as otherwise
    # workflow ACLs fails when the first non-initial action is autorun
    $workflow->attrib({ creator => $creator });

    # add the tenant information to context and attributes
    if ($tenant) {
        $workflow->attrib({ tenant => $tenant });
        $context->{PARAMS}{'tenant'} = $tenant;
    }

    OpenXPKI::Server::Context::setcontext({ workflow_id => $id, force => 1 });

    ##! 16: 'workflow id ' .  $id
    CTX('log')->workflow->info("Workflow instance $id created for $creator (type: '$type')");

    # load the first state and check for the initial action
    my $state = undef;

    my @actions = $workflow->get_current_actions;

    my $initial_action;
    if ($initial_action = $params->activity) {
        OpenXPKI::Exception->throw (
            message => 'Given activity is not an inital action to this workflow',
            params => { type => $type, action => $initial_action }
        ) unless (grep { $_ eq $initial_action } @actions);

    } elsif (scalar @actions != 1) {
        OpenXPKI::Exception->throw (
            message => "Workflow definition does not specify exactly one first activity and no activity was given",
            params => { type => $type, actions => \@actions }
        );
    } else {
        $initial_action = shift @actions;
    }

    ##! 8: "initial action: " . $initial_action

    # check the input params
    # this will buble up with an exception if validation fails
    my $wf_params = $util->validate_input_params($workflow, $initial_action, $params->params);

    ##! 16: ' initial params ' . Dumper  $wf_params
    $context->param($wf_params) if $wf_params;

    ##! 64: Dumper $workflow

    # this runs the workflow validators using the current context
    # TODO: merge with code in Workflow::execute_action, see #792
    # move back into the norun branch to check context validity!
    $workflow->validate_context_before_action($initial_action);

    # if save_initial crashes we want to see this
    if ($norun) {
        if ($norun eq 'detach') {
            ##! 16: 'Create detached'
            # call async exec, this will only crash on a fork error so we dont
            # use an eval here
            $workflow = $util->execute_activity($workflow, $initial_action, 1, 0, 'System');

        } elsif ($norun eq 'watchdog') {
            ##! 16: 'Persist and dispatch to watchdog'
            $workflow->save_initial($initial_action, 0);

        } else {
            ##! 16: 'Persist only'
            $workflow->save_initial($initial_action);
        }
    } else {
        ##! 16: 'execute initial ' . $initial_action
        # catch exceptions during execution - this might happen after
        # several autorun methods have been called in the middle of a
        # persisted workflow
        eval {
            $workflow = $util->execute_activity($workflow, $initial_action);
        };
        if ($EVAL_ERROR) {
            # Safety net: bubble up unknown exceptions.
            # We assume that all OpenXPKI::Exception that may occur have already
            # been handled properly further down the execution chain
            die $EVAL_ERROR unless (blessed $EVAL_ERROR);

            # bubble up non OXI Exceptions
            if (!$EVAL_ERROR->isa('OpenXPKI::Exception')) {
                $EVAL_ERROR->rethrow();
            }
        }
    }

    Log::Log4perl::MDC->put('wfid',  $last_id);
    Log::Log4perl::MDC->put('wftype', $last_type);

    return $util->get_wf_info(workflow => $workflow, with_ui_info => $params->ui_info);

};

sub _handle_lock {

    my $self = shift;
    my $id = shift;
    my $lock = shift;

    my $namespace = 'workflow.lock';
    my $on_error = 'die';
    my $key;
    my $expiry;

    ##! 32: $lock
    if (!ref $lock) {
       $key = $lock;
    } else {
        $key = $lock->{key};
        $namespace = $lock->{namespace} if ($lock->{namespace});

        $expiry = OpenXPKI::DateTime::get_validity({
            VALIDITY => $lock->{expiry},
            VALIDITYFORMAT => 'detect',
        })->epoch() if ($lock->{expiry});

        if ($lock->{on_error}) {
            if ($lock->{on_error} =~ m{\A(die|skip|workflow|force)\z}) {
                $on_error = $lock->{on_error};
            } else {
                CTX('log')->system->warn(sprintf "Invalid error policy %s - ignored", $lock->{on_error});
            }
        }
    }

    OpenXPKI::Exception->throw (
        message => 'Lock requested but key is empty',
        params => { namespace => $namespace }
    ) unless($key);

    ##! 32: "Use lock $namespace / $lock - $on_error"

    # we set the lock now as the related UPDATE query will create
    # an implicit lock/wait so another call with the same lock key will
    # wait here and not proceed with creating another workflow
    # it will die immediately if the lock already exists
    # if something goes wrong with the workflow later the transaction will
    # not be commited so the lock will disappear
    eval {
        CTX('api2')->set_data_pool_entry(
            namespace => $namespace,
            key => $key,
            value => $id,
            encrypt => 0,
            force => ($on_error eq 'force'),
            ($expiry ? (expiration_date => $expiry): ()),
        );
        ##! 32: 'Lock was created'
        CTX('log')->workflow->info(sprintf "Lock for workflow #%s was created with %s/%s", $id, $namespace, $key);
    };
    if ($EVAL_ERROR) {
        ##! 8: 'Error creating lock ' . $EVAL_ERROR
        return if ($on_error eq 'skip');

        my $has_lock = CTX('api2')->get_data_pool_entry(
            namespace => $namespace,
            key => $key,
        );
        if ($has_lock) {
            return $has_lock->{value} if ($on_error eq 'workflow');
            OpenXPKI::Exception->throw (
                message => 'Workflow lock already exists',
                params => { key => $key, namespace => $namespace, value => $has_lock->{value} }
            );
        }

        OpenXPKI::Exception->throw (
            message => 'Unable to obtain lock',
            params => { key => $key, namespace => $namespace, error => "$EVAL_ERROR" }
        );
    }
    return 0;

}

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Workflow::wakeup_resume_workflow;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::wakeup_resume_workflow

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 wakeup_workflow

Wakes up a workflow in C<PAUSE> state.

Reads the last action from the history and reruns it. This method is also used
by the watchdog.

By default, the workflow is executed "inline", all actions are handled and the
method returns a I<HashRef> with the UI control structure of the new workflow state.
Use parameters C<async> and/or C<wait> for "background" execution using a newly spawned process
(see below).

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID. Required.

=item * C<type> I<Str> - workflow type, specifying it will prevent another
config lookup. Optional.

=item * C<async> I<Bool> - "background" execution (asynchronously): forks a new
process. Optional.

Return I<HashRef> contains the UI control structure of the OLD workflow
state.

=item * C<wait> I<Bool> - wait for background execution to start (monitors the
database, max. 15 seconds). Optional.

Return I<HashRef> contains the UI control structure of the current state of the
running workflow. Please note that this might be the next step or any
following step as this depends on random timing, i.e. when the monitoring loop
happens to check the database again.

=back

B<Changes compared to API v1:>

=over

=item 1. Parameter C<WORKFLOW> was renamed to C<type>

=item 2. String parameter C<ASYNC> was split into two boolean parameters C<async>
and C<wait>:

    CTX('api') ->wakeup_workflow(.. ASYNC => "fork")       # old API
    CTX('api2')->wakeup_workflow(.. async => 1)            # new API

    CTX('api') ->wakeup_workflow(.. ASYNC => "watch")      # old API
    CTX('api2')->wakeup_workflow(.. async => 1, wait => 1) # new API

=back

=cut
command "wakeup_workflow" => {
    id    => { isa => 'Int', required => 1, },
    type  => { isa => 'AlphaPunct', },
    async => { isa => 'Bool', },
    wait  => { isa => 'Bool', },
} => sub {
    my ($self, $params) = @_;

    CTX('log')->system()->warn('Passing the attribute *type* to wakeup_workflow is deprecated.') if ($params->type);

    return $self->_wakeup_or_resume_workflow(1, $params->id, $params->async, $params->wait);
};

=head2 resume_workflow

Resumes a workflow that is in exception state.

For details see similar command L</wakeup_workflow>

Addtional parameter I<force> can be used to resume a workflow from I<running>
state. Do so only after doublechecking that the workflow is really not running
on any node of your cluster. YOU HAVE BEEN WARNED!

B<Changes compared to API v1:>

=over

=item 1. Unused parameter C<WORKFLOW> was removed

=item 2. String parameter C<ASYNC> was split into two boolean parameters C<async>
and C<wait>:

    CTX('api') ->wakeup_workflow(.. ASYNC => "fork")       # old API
    CTX('api2')->wakeup_workflow(.. async => 1)            # new API

    CTX('api') ->wakeup_workflow(.. ASYNC => "watch")      # old API
    CTX('api2')->wakeup_workflow(.. async => 1, wait => 1) # new API

=back

=cut
command "resume_workflow" => {
    id    => { isa => 'Int', required => 1, },
    async => { isa => 'Bool', },
    wait  => { isa => 'Bool', },
    force => { isa => 'Bool', },
} => sub {
    my ($self, $params) = @_;
    return $self->_wakeup_or_resume_workflow(0, $params->id, $params->async, $params->wait, $params->force);
};

=head2 _wakeup_or_resume_workflow

Does the work for resume and wakeup, pulls the last action from the history
and executes it.

B<Parameters>

=over

=item * C<$wakeup_mode> I<Bool> - 0 = resume workflows, 1 = wakeup paused workflows

=item * C<$id> I<Int> - workflow ID. Required.

=item * C<$async> I<Bool> - execute the workflow asynchronously, i.e. in a new
process.

=item * C<$wait> I<Bool> - only if C<$async> is set: wait until there are any
status changes in the background (monitors the database).

=back

=cut
sub _wakeup_or_resume_workflow {
    my ($self, $wakeup_mode, $id, $async, $wait, $force) = @_; # mode: resume or wakeup
    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    ##! 2: "load workflow"
    my $workflow = $util->fetch_workflow($id);

    # wakeup from watchdog is always ok
    my @caller = $self->rawapi->my_caller(1);
    ($caller[0] eq 'OpenXPKI::Server::Watchdog')
    or $util->factory->authorize_workflow({
        ACTION => $wakeup_mode ? 'wakeup' : 'resume',
        WORKFLOW => $workflow,
    })
    or OpenXPKI::Exception->throw (
        message => "No permission to ".($wakeup_mode ? 'wakeup' : 'resume')." this type of workflow",
        params => { type => $workflow->type() }
    );

    ##! 64: 'Got workflow ' . Dumper $workflow

    my $proc_state = $workflow->proc_state;

    # check if the workflow is in the correct proc state to get handled
    # 'wakeup' mode
    if ($wakeup_mode) {
        if ($proc_state ne 'pause' and $proc_state ne 'retry_exceeded') {
            OpenXPKI::Exception->throw(
                message => 'Attempt to wake up a workflow that is not in PAUSE state',
                params => { id => $id, proc_state => $proc_state }
            );
        }
    }
    # 'resume' mode
    else {
        if ($proc_state ne 'exception') {
            if ($force && $proc_state eq 'running') {
                CTX('log')->system()->warn('Resume workflow from running state');
            } else {
                OpenXPKI::Exception->throw(
                    message => 'Attempt to resume a workflow that is not in EXCEPTION state',
                    params => { id => $id, proc_state => $proc_state }
                );
            }
        }
    }

    # get the last action from the context
    my $activity = $workflow->context->param('wf_current_action');

    ##! 16: 'execute activity ' . $activity
    CTX('log')->workflow->info(sprintf(
        "%s%s workflow %s (type '%s') with activity %s",
        $wakeup_mode ? "Wakeup" : "Resume",
        $async ? ($wait ? " (async & waiting)" : " (async)") : "",
        $id, $workflow->type(), $activity
    ));

    my $updated_workflow = $util->execute_activity($workflow, $activity, $async, $wait);
    return $util->get_wf_info(id => $id, with_ui_info => 1);
}

__PACKAGE__->meta->make_immutable;

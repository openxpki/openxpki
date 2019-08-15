package OpenXPKI::Server::API2::Plugin::Workflow::execute_workflow_activity;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::execute_workflow_activity

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 execute_workflow_activity

Executes a given activity on a workflow.

By default, the activity is executed "inline", all actions are handled and the
method returns a I<HashRef> with the UI control structure of the new workflow state.
Use parameters C<async> and/or C<wait> for "background" execution using a newly spawned process
(see below).

=over

=item * C<id> I<Int> - workflow id

=item * C<workflow> I<Str> - name/type of the workflow, optional (default: read from the tables)

=item * C<activity> I<Str> - name of the action to execute

=item * C<params> I<HashRef> - parameters to be passed to the action

=item * C<ui_info> I<Bool> - set to 1 to have full information HashRef returned,
otherwise only workflow state information is returned. Default: 0

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

String parameter C<ASYNC> was split into two boolean parameters C<async>
and C<wait>:

    CTX('api') ->execute_workflow_activity(.. ASYNC => "fork")       # old API
    CTX('api2')->execute_workflow_activity(.. async => 1)            # new API

    CTX('api') ->execute_workflow_activity(.. ASYNC => "watch")      # old API
    CTX('api2')->execute_workflow_activity(.. async => 1, wait => 1) # new API

=cut
command "execute_workflow_activity" => {
    id       => { isa => 'Int', },
    workflow => { isa => 'AlphaPunct', },
    activity => { isa => 'AlphaPunct', required => 1, },
    params   => { isa => 'HashRef', },
    ui_info  => { isa => 'Bool', },
    async    => { isa => 'Bool', },
    wait     => { isa => 'Bool', },
} => sub {
    my ($self, $params) = @_;
    ##! 1: "execute_workflow_activity"

    my $wf_id       = $params->id;
    my $wf_activity = $params->activity;

    CTX('log')->system()->warn('Passing the attribute *type* to execute_workflow_activity is deprecated.') if ($params->has_workflow);

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    Log::Log4perl::MDC->put('wfid',   $wf_id);

    ##! 2: "load workflow"
    my $workflow = $util->fetch_workflow($wf_id);

    my $wf_type = $workflow->type();
    Log::Log4perl::MDC->put('wftype', $wf_type);

    # Make sure workflow is in state "manual".
    # A proc_state other than "manual" should be prevented by the UI but may
    # occur if the workflow moves on while the UI shows the old state or if the
    # user manages to fire up the same action multiple times.
    my $proc_state = $workflow->proc_state();
    if ($proc_state ne "manual") {
        OpenXPKI::Exception->throw(
            message => 'Attempt to execute activity on workflow that is not in proc_state "manual"',
            params => { wf_id => $wf_id, activity => $wf_activity, proc_state => $proc_state }
        );
    }

    # check the input params
    my $wf_params = $util->validate_input_params($workflow, $wf_activity, $params->params);
    ##! 16: 'activity params ' . $wf_params

    my $context = $workflow->context();
    $context->param($wf_params) if $wf_params;

    ##! 64: Dumper $workflow
    CTX('log')->workflow()->debug(sprintf(
        "%s of workflow activity '%s' on workflow #%s ('%s')",
        $params->async ? sprintf("Background execution (%s)", $params->wait ? "async & waiting" : "async") : "Execution",
        $wf_activity, $wf_id, $wf_type
    ));
    my $updated_workflow = $util->execute_activity($workflow, $wf_activity, $params->async, $params->wait);

    return ($params->ui_info
        ? $util->get_ui_info(workflow => $updated_workflow)
        : $util->get_workflow_info($updated_workflow)
    );
};

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Workflow::start_workflow;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::start_workflow

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;
use OpenXPKI::Debug;
use Data::Dumper;


=head1 COMMANDS

=head2 start_workflow

Start a workflow by running the initial action for an instance that was
persisted earlier with I<create_workflow_instance(norun => persit)>.

By default, the activity is executed "inline", all actions are handled and
the method returns a I<HashRef> with the UI control structure of the new
workflow state. Use parameters C<async> and/or C<wait> for "background"
execution using a newly spawned process (see below).

=over

=item * C<id> I<Int> - workflow id

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

=cut

command "start_workflow" => {
    id       => { isa => 'Int', },
    ui_info  => { isa => 'Bool', default => 0 },
    async    => { isa => 'Bool', default => 0 },
    wait     => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    ##! 1: "start"

    my $wf_id       = $params->id;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    Log::Log4perl::MDC->put('wfid', $wf_id);

    ##! 2: "load workflow"
    my $workflow = $util->fetch_workflow($wf_id);

    my $wf_type = $workflow->type();
    Log::Log4perl::MDC->put('wftype', $wf_type);

    # Make sure workflow is in state "init".
    my $proc_state = $workflow->proc_state();

    OpenXPKI::Exception->throw(
        message => 'Attempt to start workflow that is not in proc_state "init"',
        params => { wf_id => $wf_id, proc_state => $proc_state }
    ) if ($proc_state ne "init");

    my $wf_activity = $workflow->context->param( 'wf_current_action' );

    OpenXPKI::Exception->throw(
        message => 'Attempt to start workflow but no initial action is set',
        params => { wf_id => $wf_id }
    ) unless ($wf_activity);

    ##! 64: Dumper $workflow
    CTX('log')->workflow()->debug(sprintf(
        "%s of workflow activity '%s' on workflow #%s ('%s')",
        $params->async ? sprintf("Background execution (%s)", $params->wait ? "async & waiting" : "async") : "Execution",
        $wf_activity, $wf_id, $wf_type
    ));

    my $updated_workflow = $util->execute_activity($workflow, $wf_activity, $params->async, $params->wait);

    return $util->get_wf_info(workflow => $updated_workflow, with_ui_info => $params->ui_info);
};

__PACKAGE__->meta->make_immutable;

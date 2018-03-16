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

By default, the activity is executed inline and the API command returns after
all actions are handled. But you can detach the activity from the calling
process by setting C<async>: if set to I<fork> a child process will be forked
and this API command will return the UI control structure of the OLD state. If
set to I<watch> it will fork, wait until the workflow was started or 15 seconds
have elapsed and return the UI structure from the running workflow.

=over

=item * C<id> I<Int> - workflow id

=item * C<activity> I<Str> - name of the action to execute

=item * C<params> I<HashRef> - parameters to be passed to the action

=item * C<ui_info> I<Bool> - set to 1 to have full information HashRef returned,
otherwise only workflow state information is returned. Default: 0

=item * C<workflow> I<Str> - name of the workflow, optional (read from the tables)

=item * C<async> I<Bool> - set to I<fork> or I<watch> to execute the activity
asynchronously (see explanation above). Default: undef

=back

=cut
command "execute_workflow_activity" => {
    activity => { isa => 'AlphaPunct', required => 1, },
    async    => { isa => 'Str', matching => qr/(?^x: fork|watch )/, },
    id       => { isa => 'Int', },
    params   => { isa => 'HashRef', },
    ui_info  => { isa => 'Bool', },
    workflow => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;
    ##! 1: "execute_workflow_activity"

    my $wf_id       = $params->id;
    my $wf_type     = $params->has_workflow ? $params->workflow : $self->api->get_workflow_type_for_id(id => $wf_id);
    my $wf_activity = $params->activity;

    Log::Log4perl::MDC->put('wfid',   $wf_id);
    Log::Log4perl::MDC->put('wftype', $wf_type);

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    ##! 2: "load workflow"
    my $workflow = $util->fetch_workflow($wf_type, $wf_id);

    my $proc_state = $workflow->proc_state();
    # should be prevented by the UI but can happen if workflow moves while UI shows old state
    if ($proc_state ne "manual") {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_API_WORKFLOW_EXECUTE_NOT_IN_VALID_STATE',
            params => { ID => $wf_id, PROC_STATE => $proc_state }
        );
    }
    $workflow->reload_observer;

    # check the input params
    my $wf_params = $util->validate_input_params($workflow, $wf_activity, $params->params);
    ##! 16: 'activity params ' . $wf_params

    my $context = $workflow->context();
    $context->param($wf_params) if $wf_params;

    ##! 64: Dumper $workflow
    CTX('log')->workflow()->debug(sprintf(
        "%s of workflow activity '%s' on workflow #%s ('%s')",
        $params->has_async ? sprintf("Background execution (%s)", $params->async) : "Execution",
        $wf_activity, $wf_id, $wf_type
    ));
    my $updated_workflow = $util->execute_activity($workflow, $wf_activity, $params->has_async, ($params->async // "") eq 'watch');

    return ($params->ui_info
        ? $util->get_ui_info(id => $wf_id)
        : $util->get_workflow_info($updated_workflow)
    );
};

__PACKAGE__->meta->make_immutable;

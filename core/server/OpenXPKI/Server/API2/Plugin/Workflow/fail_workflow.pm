package OpenXPKI::Server::API2::Plugin::Workflow::fail_workflow;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::fail_workflow

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 fail_workflow

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=item * C<workflow> I<Str> - workflow type. Default: queried via ID

=item * C<error> I<Str> - error

=item * C<reason> I<Str> - reason

=back

Returns a I<HashRef> with workflow informations like API command L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

=cut
command "fail_workflow" => {
    id       => { isa => 'Int', required => 1, },
    error    => { isa => 'Str', },
    reason   => { isa => 'Str', },
    workflow => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $wf_id   = $params->id;
    my $reason  = $params->reason;
    my $error   = $params->error;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    CTX('log')->system()->warn('Passing the attribute *workflow* to fail_workflow is deprecated.') if ($params->has_workflow);

    # in case the workflow is in a state where the factory can not load
    # it, e.g. as the workflow graph has changed we update the database
    # here and try to reload. As this is in a DBI transaction it won't
    # be persisted if it does not work
    CTX('dbi')->update(
        table => 'workflow',
        set => { workflow_state => 'FAILURE' },
        where => { workflow_id => $wf_id },
    );

    ##! 2: "load workflow"
    my $workflow = $util->fetch_workflow($wf_id);

    $util->factory->can_access_handle($workflow->type(), 'fail')
    or OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_UI_WORKFLOW_PROPERTY_ACCESS_NOT_ALLOWED_FOR_ROLE",
        params => { type => $workflow->type(),  handle => 'fail' }
    );

    if (!$error) { $error = 'Failed by user'; }
    if (!$reason) { $reason = 'userfail'; }

    $workflow->set_failed( $error, $reason );

    CTX('log')->workflow()->info(sprintf('Failed workflow %s (type %s) with error %s', $wf_id, $workflow->type(), $error));

    return $util->get_wf_info(workflow => $workflow, with_ui_info => 1);
};

__PACKAGE__->meta->make_immutable;

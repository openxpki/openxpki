package OpenXPKI::Server::API2::Plugin::Workflow::reset_workflow;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::reset_workflow

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;


=head1 COMMANDS

=head2 reset_workflow

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=back

Returns a I<HashRef> with workflow informations like API command L<get_workflow_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info/get_workflow_info>.

=cut
command "reset_workflow" => {
    id       => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $wf_id   = $params->id;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    ##! 2: "load workflow"
    my $workflow = $util->fetch_workflow($wf_id);

    $util->factory->can_access_handle($workflow->type(), 'reset')
    or OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_UI_WORKFLOW_PROPERTY_ACCESS_NOT_ALLOWED_FOR_ROLE",
        params => { type => $workflow->type(), handle => 'reset' }
    );

    $workflow->reset_hungup();

    CTX('log')->workflow()->warn(sprintf('Forced reset of workflow %s (type %s)', $wf_id, $workflow->type()));

    return $util->get_wf_info(workflow => $workflow, with_ui_info => 1);
};

__PACKAGE__->meta->make_immutable;

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

=cut
command "fail_workflow" => {
    id       => { isa => 'Int', required => 1, },
    error    => { isa => 'Str', },
    reason   => { isa => 'Str', },
    workflow => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $wf_id   = $params->id;
    my $wf_type = $params->has_workflow ? $params->workflow : $self->api->get_workflow_type_for_id(id => $wf_id);
    my $reason  = $params->reason;
    my $error   = $params->error;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    ##! 2: "load workflow"
    my $workflow = $util->fetch_workflow($wf_type, $wf_id);

    if (!$error) { $error = 'Failed by user'; }
    if (!$reason) { $reason = 'userfail'; }

    $workflow->set_failed( $error, $reason );

    CTX('log')->workflow()->info("Failed workflow $wf_id (type '$wf_type') with error $error");

    return $util->get_ui_info(workflow => $workflow);
};

__PACKAGE__->meta->make_immutable;

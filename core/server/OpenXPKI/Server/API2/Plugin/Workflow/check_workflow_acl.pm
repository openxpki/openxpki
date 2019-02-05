package OpenXPKI::Server::API2::Plugin::Workflow::check_workflow_acl;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::check_workflow_acl

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;


=head1 COMMANDS

=head2 check_workflow_acl

Check if the workflow can be accessed by the current session user.

Return a literal 0 or 1 weather the user is allowed.
Returns undef if workflow type, creator or acl is undefined.

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=back

=cut
command "check_workflow_acl" => {
    id => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $wf_type = $self->api->get_workflow_type_for_id(id => $params->id );
    return unless $wf_type;

    my $wf_creator = $self->api->get_workflow_creator(id => $params->id );
    return unless $wf_creator;

    return CTX('workflow_factory')->get_factory()->check_acl( $wf_type, $wf_creator );

};

__PACKAGE__->meta->make_immutable;

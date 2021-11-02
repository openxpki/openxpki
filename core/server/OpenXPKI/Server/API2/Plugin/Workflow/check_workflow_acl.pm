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

=item * C<tenant> I<Str> - tenant

If set to a tenant name the workflow must be owned by this tenant.
Otherwise, the workflows tenant must be accessible by the current user.

=back

=cut
command "check_workflow_acl" => {
    id => { isa => 'Int', required => 1, },
    tenant => { isa => 'Str' },
} => sub {
    my ($self, $params) = @_;

    my $wf_type = $self->api->get_workflow_type_for_id(id => $params->id );
    return unless $wf_type;

    my $wf_creator = $self->api->get_workflow_creator(id => $params->id );
    return unless $wf_creator;

    my $wf_tenant = $self->api->get_workflow_tenant(id => $params->id );

    my $user;
    $user = {
        user => CTX('session')->data->user,
        role => (CTX('session')->data->role // 'Anonymous'),
        tenant => $params->tenant
    } if ($params->has_tenant);

    return CTX('workflow_factory')->get_factory()->can_access_workflow({
        type =>    $wf_type,
        creator => $wf_creator,
        tenant =>  $wf_tenant
    }, $user);

};

__PACKAGE__->meta->make_immutable;

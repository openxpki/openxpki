package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 get_workflow_info

Querys workflow engine and workflow config for the given workflow and returns a
I<HashRef> with informations:



The workflow can be specified via ID or type.

B<Parameters>

=over

=item * C<id> I<Int> - ID of the workflow to query

=item * C<type> I<Str> - type of the workflow to query

=item * C<with_attributes> I<Bool> - set to 1 to also return workflow attributes.
Default: 0

=item * C<activity> I<Str> - only return informations about this workflow action.
Default: all actions available in the current state.

Note: you have to prepend the workflow prefix to the action separated by an
underscore.

=back

B<Changes compared to API v1:>

=over

=item * parameter C<ATTRIBUTE> was renamed to C<with_attributes>.

=item * parameter C<UIINFO> was removed (previously unused).

=item * parameter C<WORKFLOW> was removed (old API spec and code did not match and it
was only used in two places).

=back

=cut
command "get_workflow_info" => {
    id        => { isa => 'Int', },
    type      => { isa => 'AlphaPunct', },
    attribute => { isa => 'Bool', default => 0, },
    activity  => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    OpenXPKI::Exception->throw(
        message => "One of the parameters 'type' or 'id' must be specified",
    ) unless ($params->has_id or $params->has_type);

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;
    return $util->get_workflow_ui_info({
        $params->has_id       ? (ID => $params->id) : (),
        $params->has_type     ? (TYPE => $params->type) : (),
        $params->has_activity ? (ACTIVITY => $params->activity) : (),
        ATTRIBUTE => $params->attribute,
    });
};

__PACKAGE__->meta->make_immutable;

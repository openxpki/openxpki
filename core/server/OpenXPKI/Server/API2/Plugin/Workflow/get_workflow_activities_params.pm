package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_activities_params;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_activities_params

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 get_workflow_activities_params

B<Parameters>

=over

=item * C<workflow> I<Str> - workflow type

=item * C<id> I<Int> - workflow ID

=back

=cut
command "get_workflow_activities_params" => {
    workflow => { isa => 'AlphaPunct', },
    id       => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $wf_id = $params->id;

    CTX('log')->system()->warn('Passing the attribute *workflow* to get_workflow_activities_params is deprecated.') if ($params->has_workflow);

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;
    my $workflow = $util->fetch_workflow($wf_id);

    my @list = ();

    for my $action ( $workflow->get_current_actions() ) {
        my $fields = [];
        for my $field ($workflow->get_action_fields( $action ) ) {
            push @{ $fields }, {
                name        => $field->name(),
                label       => $field->label(),
                description => $field->description(),
                type        => $field->type(),
                requirement => $field->requirement(),
            };
        };
        push @list, $action, $fields;
    }
    return \@list;
};

__PACKAGE__->meta->make_immutable;

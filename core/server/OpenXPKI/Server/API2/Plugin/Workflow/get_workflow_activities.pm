package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_activities;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_activities

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 get_workflow_activities

B<Parameters>

=over

=item * C<workflow> I<Str> - workflow type

=item * C<id> I<Int> - workflow ID

=back

=cut
command "get_workflow_activities" => {
    workflow => { isa => 'AlphaPunct', },
    id       => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    CTX('log')->system()->warn('Passing the attribute *workflow* to get_workflow_activities is deprecated.') if ($params->has_workflow);

    my $wf_id = $params->id;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;
    my $workflow = $util->fetch_workflow($wf_id);

    my @list = $workflow->get_current_actions();
    return \@list;
};

__PACKAGE__->meta->make_immutable;

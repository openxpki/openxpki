package OpenXPKI::Server::API2::Plugin::Workflow::list_workflow_titles;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::list_workflow_titles

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 list_workflow_titles

Returns a I<HashRef> containing all available workflow titles including
a description.

Return structure:

    {
        title => "description",
        ...
    }

=cut
command "list_workflow_titles" => {
} => sub {
    my ($self, $params) = @_;

    return CTX('workflow_factory')->get_factory->list_workflow_titles;
};

__PACKAGE__->meta->make_immutable;

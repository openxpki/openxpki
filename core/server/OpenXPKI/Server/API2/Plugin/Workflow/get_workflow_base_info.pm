package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_base_info;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_base_info

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 get_workflow_base_info

Querys workflow config for the given workflow and returns a
I<HashRef> with informations:

    {
        workflow => {
                type        => ...,
                id          => ...,
                state       => ...,
                label       => ...,
                description => ...,
            },
            activity => { ... },
            state => {
                button => { ... },
                option => [ ... ],
                output => [ ... ],
            },
        }
    }

B<Parameters>

=over

=item * C<type> I<Str> - type of the workflow to query

=back

=cut
command "get_workflow_base_info" => {
    type      => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;
    return $util->get_ui_base_info($params->type);
};

__PACKAGE__->meta->make_immutable;

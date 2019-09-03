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

Querys workflow config for the given workflow type and returns a
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

=item * C<type> I<Str> - workflow type

=back

=cut
command "get_workflow_base_info" => {
    type      => { isa => 'AlphaPunct', },
} => sub {
    my ($self, $params) = @_;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    ##! 2: 'start'

    # TODO we might use the OpenXPKI::Workflow::Config object for this
    # Note: Using create_workflow shreds a workflow id and creates an orphaned entry in the history table

    if (not $util->factory->authorize_workflow({ ACTION => 'create', TYPE => $params->type })) {
        OpenXPKI::Exception->throw(
            message => 'User is not authorized to fetch workflow info',
            params => { type => $params->type }
        );
    }

    my $state = 'INITIAL';
    my $head = CTX('config')->get_hash([ 'workflow', 'def', $params->type, 'head' ]);

    # fetch actions in state INITIAL from the config
    my $wf_config = $util->factory->_get_workflow_config($params->type);
    my @actions;
    for my $state (@{$wf_config->{state}}) {
        next unless $state->{name} eq 'INITIAL';
        @actions = ($state->{action}->[0]->{name});
        last;
    }

    return {
        workflow => {
            type        => $params->type,
            id          => 0,
            state       => $state,
            label       => $head->{label},
            description => $head->{description},
        },
        # activity =>
        # state =>
        %{ $util->get_activity_and_state_info($params->type, $head->{prefix}, $state, \@actions, undef) },
    };
};

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_data;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_data

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;

=head1 COMMANDS

=head2 get_workflow_data

Return all "volatile" information for a given workflow id as
I<HashRef>:
    {
        workflow => {
                type        => ...,
                id          => ...,
                state       => ...,
                last_update => ...,
                proc_state  => ...,
                count_try   => ...,
                wake_up_at  => ...,
                reap_at     => ...,
                context     => { ... },
                attribute   => { ... },
            },
        }
    }

B<Parameters>

=over

=item * C<id> I<Int> - ID of the workflow to query

=back

=cut
command "get_workflow_data" => {
    id        => { isa => 'Int', required => 1, },
    with_attributes => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    my $workflow = CTX('workflow_factory')->get_workflow({ ID => $params->id });

    return {
        workflow => {
            type        => $workflow->type,
            id          => $workflow->id,
            state       => $workflow->state,
            last_update => $workflow->last_update->iso8601,
            proc_state  => $workflow->proc_state,
            count_try   => $workflow->count_try,
            wake_up_at  => $workflow->wakeup_at,
            reap_at     => $workflow->reap_at,
            context     => { %{$workflow->context->param } },
            attribute   => $workflow->attrib
        }
    };

};

__PACKAGE__->meta->make_immutable;

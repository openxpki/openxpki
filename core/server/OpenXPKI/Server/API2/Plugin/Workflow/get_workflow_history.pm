package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_history;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_history

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_workflow_history

Returns an I<ArrayRef> of I<HashRefs> of the workflow history, ordered by date:

    [
        {
            workflow_hist_id        => ...,
            workflow_id             => ...,
            workflow_action         => ...,
            workflow_description    => ...,
            workflow_state          => ...,
            workflow_user           => ...,
            workflow_history_date   => ...,
        },
        {
            ...
        },
    ]

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=item * C<noacl> I<Bool> -

=back

=cut
command "get_workflow_history" => {
    id    => { isa => 'Int', required => 1, },
    noacl => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    my $wf_id = $params->id;

    if (not $params->noacl) {
        my $role = CTX('session')->data->role || 'Anonymous';
        my $wf_type = $self->api->get_workflow_type_for_id(id => $wf_id);
        my $allowed = CTX('config')->get([ 'workflow', 'def', $wf_type, 'acl', $role, 'history' ] );

        if (not $allowed) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_UI_UNAUTHORIZED_ACCESS_TO_WORKFLOW_HISTORY',
                params  => {
                    id => $wf_id,
                    type => $wf_type,
                    user => CTX('session')->data->user,
                    role => $role
                },
            );
        }
    }

    my $history = CTX('dbi')->select(
        from => 'workflow_history',
        columns => [ '*' ],
        where => { workflow_id => $wf_id },
        order_by => [ 'workflow_history_date', 'workflow_hist_id' ],
    )->fetchall_arrayref({});

    ##! 64: 'history: ' . Dumper $history
    return $history;
};

__PACKAGE__->meta->make_immutable;

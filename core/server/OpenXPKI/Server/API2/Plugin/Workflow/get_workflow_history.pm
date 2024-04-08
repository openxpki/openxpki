package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_history;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_history

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;



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

=back

=cut
command "get_workflow_history" => {
    id    => { isa => 'Int', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $wf_id = $params->id;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    $self->api->check_workflow_acl( id => $wf_id )
    or OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_UI_WORKFLOW_ACCESS_NOT_ALLOWED_FOR_USER',
    );

    my $wf_type = CTX('api2')->get_workflow_type_for_id( id => $wf_id );

    $util->factory->can_access_handle($wf_type, 'history')
    or OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_UI_WORKFLOW_PROPERTY_ACCESS_NOT_ALLOWED_FOR_ROLE',
        params => { type => $wf_type,  handle => 'history' }
    );

    # TODO - this duplicates code from the Persister and depends on the
    # actual implementation. Should likely be replaced by persister call
    my $history = CTX('dbi')->select_hashes(
        from => 'workflow_history',
        columns => [ '*' ],
        where => { workflow_id => $wf_id },
        order_by => [ 'workflow_history_date', 'workflow_hist_id' ],
    );

    ##! 64: 'history: ' . Dumper $history
    return $history;
};

__PACKAGE__->meta->make_immutable;

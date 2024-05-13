package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info;
use OpenXPKI -plugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_info

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;
use OpenXPKI::Server::API2::Plugin::Workflow::Util;



=head1 COMMANDS

=head2 get_workflow_info

Querys workflow engine and workflow config for the given workflow and returns a
I<HashRef> with informations:

    {
        workflow => {
            type        => ...,
            id          => ...,
            state       => ...,
            label       => ...,
            description => ...,
            last_update => ...,
            proc_state  => ...,
            count_try   => ...,
            wake_up_at  => ...,
            reap_at     => ...,
            archive_at  => ...,
            context     => { ... },
            attribute   => { ... },   # only if "with_attributes => 1"
        },

        # only if "with_ui_info => 1":
        handles  => [ ... ],
        activity => { ... },
        state => {
            button => { ... },
            option => [ ... ],
            output => [ ... ],
        },
    }

B<Parameters>

=over

=item * C<id> I<Int> - ID of the workflow to query

=item * C<with_attributes> I<Bool> - set to 1 to also return workflow attributes.
Default: 0

=item * C<activity> I<Str> - only return informations about this workflow action.
Default: all actions available in the current state.

Note: you have to prepend the workflow prefix to the action separated by an
underscore.

=item * C<with_ui_info> I<Bool> - set to 1 to get the extra UI informations about
workflow actions and state

=back

B<Changes compared to API v1:>

=over

=item * parameter C<TYPE> was removed (use API command L<get_workflow_base_info|OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_base_info>
instead to get workflow info by type).

=item * parameter C<WORKFLOW> was removed (old API spec and code did not match and it
was only used in two places).

=item * parameter C<ATTRIBUTE> was renamed to C<with_attributes>.

=item * parameter C<UIINFO> was removed (previously unused).

=back

=cut
command "get_workflow_info" => {
    id        => { isa => 'Int', required => 1, },
    activity  => { isa => 'AlphaPunct', },
    with_attributes => { isa => 'Bool', default => 0, },
    with_ui_info => { isa => 'Bool', default => 0, },
} => sub {
    my ($self, $params) = @_;

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    return $util->get_wf_info(
        id => $params->id,
        $params->has_activity ? (activity => $params->activity) : (),
        with_attributes => $params->with_attributes,
        with_ui_info => $params->with_ui_info,
    );
};

__PACKAGE__->meta->make_immutable;

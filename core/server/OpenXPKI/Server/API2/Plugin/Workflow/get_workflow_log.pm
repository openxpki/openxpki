package OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_log;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_workflow_log

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_workflow_log

Returns the workflow log for a given workflow id, by default you get the last
50 items of the log sorted by newest item first.

Set C<limit> to the number of lines expected or 0 to get all lines (might be
huge!).

The return value is a list of arrays with a fixed order of fields:
TIMESTAMP, PRIORITY, MESSAGE

B<Parameters>

=over

=item * C<id> I<Int> - workflow ID

=item * C<limit> I<Int> - limit the log entries. Default: 0 = unlimited

=item * C<reverse> I<Bool> - set to 1 to have the oldest entry first

=back

=cut
command "get_workflow_log" => {
    id      => { isa => 'Int', required => 1, },
    limit   => { isa => 'Int', },
    reverse => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    ##! 1: "get_workflow_log"
    my $wf_id = $params->id;

    # ACL check
    my $wf_type = $self->api->get_workflow_type_for_id(id => $wf_id);

    my $role = CTX('session')->data->role || 'Anonymous';
    my $allowed = CTX('config')->get([ 'workflow', 'def', $wf_type, 'acl', $role, 'techlog' ] );

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_UI_UNAUTHORIZED_ACCESS_TO_WORKFLOW_LOG',
        params  => {
            'ID' => $wf_id,
            'TYPE' => $wf_type,
            'USER' => CTX('session')->data->user,
            'ROLE' => $role
        },
    ) unless $allowed;

    # Reverse is inverted as we want to have reversed order by default
    my $order = $params->reverse ? 'ASC' : 'DESC';

    # default: limit to 50 rows
    my %limit_cond = (limit => 50);
    if ($params->has_limit) {
        # 0 = unlimited
        if ($params->limit == 0) {
            %limit_cond = ();
        }
        # x = take user value
        else {
            %limit_cond = (limit => $params->limit);
        }
    }

    my $sth = CTX('dbi')->select(
        from => 'application_log',
        columns => [ qw( logtimestamp priority message ) ],
        where => { workflow_id => $wf_id },
        order_by => [ "logtimestamp $order", "application_log_id $order" ],
        %limit_cond,
    );

    my @log;
    while (my $entry = $sth->fetchrow_hashref) {
        # remove the package and session info from the message
        $entry->{message} =~ s/\A\[OpenXPKI::.*\]//;
        push @log, [
            $entry->{logtimestamp},
            Log::Log4perl::Level::to_level($entry->{priority}),
            $entry->{message}
        ];
    }

    return \@log;
};

__PACKAGE__->meta->make_immutable;

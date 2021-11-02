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

    my $util = OpenXPKI::Server::API2::Plugin::Workflow::Util->new;

    ##! 1: "get_workflow_log"
    my $wf_id = $params->id;

    $self->api->check_workflow_acl( id => $wf_id )
    or OpenXPKI::Exception->throw (
        message => 'I18N_OPENXPKI_UI_WORKFLOW_ACCESS_NOT_ALLOWED_FOR_USER',
    );

    # ACL check
    my $wf_type = CTX('api2')->get_workflow_type_for_id(id => $wf_id);
    $util->factory->can_access_handle($wf_type, 'techlog')
    or OpenXPKI::Exception->throw (
        message => "I18N_OPENXPKI_UI_WORKFLOW_PROPERTY_ACCESS_NOT_ALLOWED_FOR_ROLE",
        params => { type => $wf_type,  handle => 'techlog' }
    );

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

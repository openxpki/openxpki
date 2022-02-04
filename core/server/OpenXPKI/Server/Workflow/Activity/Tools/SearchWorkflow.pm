package OpenXPKI::Server::Workflow::Activity::Tools::SearchWorkflow;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Workflow::Exception qw(configuration_error);


sub execute {

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || 'search_result';
    my $mode = $self->param('mode') || 'id';

    my $query;
    if ($self->param('wf_type')) {
        $query->{type} = $self->param('wf_type');
    }

    if ($self->param('wf_state')) {
        $query->{state} = $self->param('wf_state');
    }

    if ($self->param('wf_proc_state')) {
        $query->{proc_state} = $self->param('wf_proc_state');
    }

    if ($self->param('realm')) {
        ##! 16: 'Adding realm ' . $self->param('realm')
        $query->{pki_realm} = $self->param('realm');
    }

    if ($self->param('order')) {
        ##! 16: 'Adding order clause ' . $self->param('order')
        $query->{order} = $self->param('order');
    }

    if ($self->param('limit')) {
        ##! 16: 'Adding limit ' . $self->param('limit')
        $query->{limit} = $self->param('limit');
    }

    my $attr;
    if ($self->param('wf_creator')) {
        $attr->{'creator'} = ~~ $self->param('wf_creator');
    }

    if (defined $self->param('tenant')) {
        $query->{tenant} = $self->param('tenant');
    } elsif ($workflow->attrib('tenant')) {
        $query->{tenant} = $workflow->attrib('tenant');
    }

    foreach my $key ($self->param()) {
        ##! 16: 'Param key ' . $key
        next unless $key =~ /attr_(\w+)/;
        $attr->{$1} = ~~ $self->param($key);
    }

    $query->{attribute} = $attr;

    ##! 16: 'Query ' . Dumper $query

    my $result = CTX('api2')->search_workflow_instances( %$query );

    ##! 64: 'Result ' . Dumper $result

    my @ids = map { ($_->{'workflow_id'} != $workflow->id()) ? ($_->{'workflow_id'}) : () } @{$result};

    ##! 32: 'Ids ' . Dumper \@ids

    # check if self was the only match so its empty now
    if (!scalar @ids) {

        ##! 16: 'No result in id mode - unset ' .$target_key
        $context->param( $target_key => undef );

    } elsif ($mode eq 'list') {

        $context->param( $target_key => \@ids );

    } else {

        if (scalar @ids > 1) {
            configuration_error('Ambigous configuration - more than one result found');
        } else {
            $context->param( $target_key => $ids[0] );
        }
    }
    return 1;

}


1;

__END__;

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SearchWorkflow

=head1 Description

Search the workflow table based on given conditions. The default is to
search for a single workflow and get its ID back. If you want to search
for multiple workflows or need extra information you can pass the I<mode>
parameter. The running workflow is always removed from the result.

If no result is found, the targer_key is set to undef.

Also check the documentation of the search_workflow_instances API method.

=head2 Search Modes

=over

=item id

Expect a single (or no) result from the query. If the given query returns
more than one item, the search fails with a configuration error.

=item list

Return the ids of the workflows as list.

=back

=head2 Activity Parameter

=over

=item mode

One of I<id, list>, see description.

=item realm

The realm to search in, the default is the current realm. You can use the
special word I<_any> to search in all realms. Use this with caution!

=item order

Order the result set by this column

=item limit

Integer, limit the size of the result set to max items

=item target_key

Context key to write the search result to, default is search_result.

=item wf_type, wf_state, wf_creator, wf_proc_state

Values are passed as arguments for the respective workflow properties.

=item tenant

The tenant to search for, the default is to use the tenant of the
current workflow.

=item attr_*

Any parameter starting with the prefix I<attr_> is used as query condition
to the workflow attributes table, the prefixed is stripped, the remainder
is used as attribute key. Values are passed as full text match.

=back

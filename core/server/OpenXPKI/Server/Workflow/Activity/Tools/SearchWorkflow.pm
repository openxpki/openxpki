package OpenXPKI::Server::Workflow::Activity::Tools::SearchWorkflow;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;
use Workflow::Exception qw(configuration_error);


sub execute {

    my $self = shift;
    my $workflow = shift;

    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || 'search_result';

    my $query;
    if ($self->param('wf_type')) {
        $query->{TYPE} = $self->param('wf_type');
    }

    if ($self->param('wf_state')) {
        $query->{STATE} = $self->param('wf_state');
    }

    if ($self->param('realm')) {
        ##! 16: 'Adding realm ' . $self->param('realm')
        $query->{PKI_REALM} = $self->param('realm');
    }

    my @attr;
    if ($self->param('wf_creator')) {
        push @attr, { KEY => 'creator', VALUE => ~~ $self->param('wf_creator') };
    }

    foreach my $key ($self->param()) {
        ##! 16: 'Param key ' . $key
        next unless $key =~ /attr_(\w+)/;
        push @attr, { KEY => $1, VALUE => ~~ $self->param($key) };
    }

    $query->{ATTRIBUTE} = \@attr;

    ##! 16: 'Query ' . Dumper $query

    my $result = CTX('api')->search_workflow_instances( $query );

    ##! 64: 'Result ' . Dumper $result

    my @ids = map { ($_->{'WORKFLOW.WORKFLOW_SERIAL'} != $workflow->id()) ? ($_->{'WORKFLOW.WORKFLOW_SERIAL'}) : () } @{$result};

    ##! 32: 'Ids ' . Dumper \@ids

    # check if self was the only match so its empty now
    if (!scalar @ids) {
        $context->param( $target_key => undef );
    } elsif ($self->param('mode') eq 'list') {

        $context->param( $target_key => OpenXPKI::Serialization::Simple->new()->serialize(\@ids) );

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

=item target_key

Context key to write the search result to, default is search_result.

=item wf_type, wf_state, wf_creator

Values are passed as arguments for the respective workflow properties.

=item attr_*

Any parameter starting with the prefix I<attr_> is used as query condition
to the workflow attributes table, the prefixed is stripped, the remainder
is used as attribute key. Values are passed as full text match.

=back
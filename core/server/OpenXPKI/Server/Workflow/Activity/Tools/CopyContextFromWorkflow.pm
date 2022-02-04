package OpenXPKI::Server::Workflow::Activity::Tools::CopyContextFromWorkflow;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    ##! 1: 'start'

    my $params = $self->param();
    ##! 16: ' parameters: ' . Dumper $params

    my $wf_id = $params->{workflow_id};
    delete $params->{workflow_id};
    my $no_acl = $params->{no_acl} || 0;
    delete $params->{no_acl};

    my @context_keys = values %{$params};

    my $sth = CTX('dbi')->select(
        from => "workflow_context",
        columns => [ "workflow_context_key", "workflow_context_value" ],
        where => {
            workflow_id => $wf_id,
            workflow_context_key => \@context_keys,
        },
    );

    my $source = { workflow_id => $wf_id };
    while (my $row = $sth->fetchrow_arrayref) {
        $source->{$row->[0]} = $row->[1];
    }

  KEY:
    foreach my $key (keys %{$params}) {

        ##! 16: 'Key ' . $key
        my $source_key = $self->param($key);

        if (defined $source->{$source_key}) {
            $context->param({ $key => $source->{$source_key} });
            CTX('log')->application()->debug("Setting context $key to " . $source->{$source_key} );
        }
    }

    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CopyContextFromWorkflow

=head1 Description

Copy context parameters from another workflow - uses direct database access
and therefore works only with the default persister!


=head2 Configuration

    class: OpenXPKI::Server::Workflow::Activity::Tools::CopyContextFromWorkflow
    param:
       workflow_id: 12345
       no_acl: 1
       this_context_key: other_context_key
       this_second_context_key: other_context_second_key


This will create two new context items I<this_context_key> and
I<this_second_context_key> with the values of I<other_context_key>
and I<other_context_second_key> from Workflow 12345.

=head2 Activity Parameters

Those named parameters are used to control the behaviour of the class,
all other parameters are used as part of the map to be copied.

=over

=item workflow_id

Id of the workflow to retrieve the context items from.

=item no_acl B<(not implemented yet!)>

Weather to use ACL checks or not, reserved for later use - no acl check are done!

=back



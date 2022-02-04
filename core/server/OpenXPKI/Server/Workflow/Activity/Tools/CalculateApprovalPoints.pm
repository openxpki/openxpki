package OpenXPKI::Server::Workflow::Activity::Tools::CalculateApprovalPoints;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Serialization::Simple;


sub execute {

    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();

    my $target_key = $self->param('target_key') || 'approval_points';

    my $serializer = OpenXPKI::Serialization::Simple->new();

    # TODO - might be useful to have options to weight/filter approvals

    my $approval_points = 0;
    if (my $approvals = $context->param('approvals')) {

        if (OpenXPKI::Serialization::Simple::is_serialized($approvals)) {
            $approvals = OpenXPKI::Serialization::Simple->new()->deserialize($approvals);
        }

        if (ref $approvals eq 'ARRAY') {
            foreach my $approval (@{$approvals}) {
                if (defined $approval->{points}) {
                    $approval_points += $approval->{points};
                } else {
                    $approval_points += 1;
                }
            }
        }
    }

    if (!$approval_points) {
        CTX('log')->application()->debug('No approvals or value in invalid format!');
    } else {
        CTX('log')->application()->info(sprintf ('Approval points for workflow %01d: %01d', $workflow->id, $approval_points));
    }

    $context->param({ $target_key => $approval_points });


    return 1;

}

1;
__END__;


=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::CalculateApprovalPoints

=head1 Description

Generate a numeric value (approval points) from the list of approvals.
By default each approval is worth one point unless the record contains a
parameter I<points> inside.

=head1 Configuration

=head2 Activity Parameter

=over

=item target_key

Context key to write the approval points to, default is I<approval_points>.

=back

=head2 Context Items

=over

=item approvals

The serialized list of approvals, as created by the Approve activity.

=back

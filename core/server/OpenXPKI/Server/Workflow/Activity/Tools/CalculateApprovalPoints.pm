package OpenXPKI::Server::Workflow::Activity::Tools::CalculateApprovalPoints;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;


sub execute {
    
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();
    
    my $target_key = $self->param('target_key') || 'approval_points';
     
    my $serializer = OpenXPKI::Serialization::Simple->new();
    
    # TODO - might be useful to have options to weight/filter approvals
    
    my $approvals = 0;
    if ($context->param('approvals')) {
        
        if ($context->param('approvals') && !ref $context->param('approvals')) {
            $approvals = scalar ( @{ $serializer->deserialize( $context->param('approvals') ) } );
        } elsif(ref $context->param('approvals') eq 'ARRAY') {
            $approvals = scalar ( @{$context->param('approvals')} );
        } else {
            CTX('log')->log(
                MESSAGE => 'No approvals or value in invalid format!', 
                PRIORITY => 'debug',
                FACILITY => 'application'
            );
        }
    }
     
    CTX('log')->log(
        MESSAGE => sprintf ('Approval points for workflow %01d: %01d', $workflow->id, $approvals), 
        PRIORITY => 'info',
        FACILITY => 'application'
    );

    return 1;

}

1;
__END__;


=head1 Name 

OpenXPKI::Server::Workflow::Activity::Tools::CalculateApprovalPoints

=head1 Description 

Generate a numeric value (approval points) from the list of approvals. 
Each approval is worth one point.
  
=head1 Configuration

=head2 Activity Parameter

=over 

=item target_key

Context key to write the approval points to, default is I<approval_points>.

=back

=head2 Context Items

=item approvals

The serialized list of approvals, as created by the Approve activity.

=back     

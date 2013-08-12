# OpenXPKI::Server::Workflow::Activity::SCEPv2::CalcApprovals
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::CalcApprovals;

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

=head1 Name 

OpenXPKI::Server::Workflow::Activity::SCEPv2::CalcApprovals

=head1 Description 

Check if the request has sufficient approval points, the required 
value for approval points can be set via parameter (approval_points). 
Default is one approval.  
   
Approval points are gathered from two sources:

=over 

=item eligibility check for initial enrollment

One approval point if signer_sn_matches_csr and eligible_for_initial_enroll 
(as evaluated by Activity::SCEPv2::EvaluateEligability) flags are true.

=item eligibility check for renewal

One approval point if signer_sn_matches_csr is false and eligible_for_renewal 
(as evaluated by Activity::SCEPv2::EvaluateEligability) is true. 

=item manual approval

Each manual operator approval given in the workflow counts as one approval.

=back     

=cut

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $context = $workflow->context();
     
    my $approval_points = $self->param('approval_points') || 1;  
    
    my $approvals = 0;
    if ( $context->param('signer_sn_matches_csr' ) && $context->param('eligible_for_initial_enroll' ) ) {
        ##! 16: 'auto approve for initial enrollment'
        $approvals = 1;
        CTX('log')->log(
            MESSAGE => 'SCEP auto approval for initial enrollment of ' . $context->param('cert_subject'),
            PRIORITY => 'info',
            FACILITY => 'audit',
        ) 
    } elsif ( !$context->param('signer_sn_matches_csr' ) && $context->param('eligible_for_renewal' ) ) {
        ##! 16: 'auto approve for renewal'        
        $approvals = 1;
        CTX('log')->log(
            MESSAGE => 'SCEP auto approval for renwal of ' . $context->param('cert_subject'),
            PRIORITY => 'info',
            FACILITY => 'audit',
        )
    } 
    
    # Look for manual approvals    
    my $serializer = OpenXPKI::Serialization::Simple->new();
    
    if ($context->param('approvals')) {
        my @manual_approvals = @{ $serializer->deserialize( $context->param('approvals') ) };
        ##! 16: 'Manual approval count: ' . scalar (@manual_approvals)
        $approvals += scalar (@manual_approvals);
    }
    
    ##! 16: 'Approval result: ' . $approvals . '/' . $approval_points 
    if ($approvals < $approval_points) {
        $context->param('have_all_approvals' => '0');    
        CTX('log')->log(
            MESSAGE => 'SCEP insufficient approval points for ' . $context->param('cert_subject'),
            PRIORITY => 'info',
            FACILITY => 'audit',
        );    
    } else {
        $context->param('have_all_approvals' => '1');    
        CTX('log')->log(
            MESSAGE => 'SCEP enough approval points for  ' . $context->param('cert_subject'),
            PRIORITY => 'info',
            FACILITY => 'audit',
        );
    }
    
    $context->param('todo_kludge_num_approvals' => 'fix in OpenXPKI::Server::Workflow::Activity::SCEPv2::CalcApprovals');

    return 1;

}

1;

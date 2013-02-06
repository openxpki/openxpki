# OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility;
        
use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    
    my $context   = $workflow->context();
    
    # TODO - do some useful stuff here     
    $context->param('eligible_for_initial_enroll' => 1);
    $context->param('eligible_for_renewal' => 1);   
    
    $context->param('todo_kludge_eligible_for_initial_enroll' => 'fix in Activity::SCEPv2::EvaluateEligability' );
    $context->param('todo_kludge_eligible_for_renewal'  => 'fix in Activity::SCEPv2::EvaluateEligability');
    
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateEligibility

=head1 Description

Stub to check the eligability to do an enrollment / renewal

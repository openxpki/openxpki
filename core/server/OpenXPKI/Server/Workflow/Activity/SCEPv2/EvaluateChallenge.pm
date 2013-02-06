# OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateChallenge
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateChallenge;

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
    
    my $challenge_password = $context->param('_challenge_password');
    
    ##! 64: 'checking existance: ' . $challenge_password
    if (!$challenge_password) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SCEP_EVALUATE_CHALLENGE_UNDEFINED',
        );
    }
 
    # TODO - do some useful stuff here     
    $context->param('valid_chall_pass' => 1);
    $context->param('todo_kludge_challenge_password_check'  => 'fix in Activity::SCEPv2::EvaluateChallenge');
    
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::EvaluateChallenge

=head1 Description

Stub to check the validity of the challenge password

# OpenXPKI::Server::Workflow::Activity::Tools::Notify
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Notify;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Notification::Handler;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    
    
    my $message    = $self->param('message');
    ##! 16: 'message: ' . $message

    if (! defined $message) {
        OpenXPKI::Exception->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_NOTIFY_MESSAGE_UNDEFINED',
        );
    }
        
    my $ser  = OpenXPKI::Serialization::Simple->new();
    # Look if there are stored notification handles
    my $handles;
    if ($workflow) {
        my $notify = $context->param('wfl_notify');
        $handles = $ser->deserialize( $notify  ) if ($notify);
        ##! 32: 'Found persisted data: ' . Dumper $handles  
    }
    
    # Re-Assign the handles from the return value 
    $handles = CTX('notification')->notify({
        MESSAGE => $message,
        WORKFLOW => $workflow,         
        TOKEN => $handles,
    });
        
    if (defined $handles) {
        ##! 32: 'Write back persisted data: ' . Dumper $handles          
        $context->param( 'wfl_notify' => $ser->serialize( $handles ) );
    }
    
}


1;
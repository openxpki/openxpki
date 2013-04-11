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
    my $params = $self->param();
    
    my $ser  = OpenXPKI::Serialization::Simple->new();
    
    my $message  = $params->{'message'};
    ##! 16: 'message: ' . $message

    if (! defined $message) {
        OpenXPKI::Exception->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_NOTIFY_MESSAGE_UNDEFINED',
        );
    }
    
    
    
    ##! 32: 'Params ' . Dumper $params
    # Check for mapping params
    my $vars = {};
    foreach my $key (keys %{$params}) {
        if ($key !~ /^_map_(.*)/) { next; }
        my $name = $1;
        my $val = $params->{$key};
        ##! 8: 'Found param ' . $name . ' - value : ' . $val
                
        # copy from context?
        if ($val =~ /^\$(\S+)/) {
            my $ctx = $1;
            ##! 16: 'resolve context key ' . $ctx              
            if ($context->param($ctx) =~ m{ \A HASH | \A ARRAY }xms) {
                # need deserialize
                ##! 32: ' needs deserialize '                 
                $vars->{$name} = $ser->deserialize( $context->param($ctx) );
            } else {
                $vars->{$name} = $context->param($ctx);    
            }
        } else { 
            $vars->{$name} = $val;
        } 
        
        
    }
    ##! 16: 'Extended vars: ' . Dumper $vars  
    
        
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
        DATA => $vars
    });
        
    if (defined $handles) {
        ##! 32: 'Write back persisted data: ' . Dumper $handles          
        $context->param( 'wfl_notify' => $ser->serialize( $handles ) );
    }
    
}

1;


__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Notify

=head1 Description

Trigger notifications using the configured notifcation backends.

=head2 Message 

Specifiy the name of the message template to send using the I<message> parameter.

=head2 Additional parameters

To make arbitrary value available for the templates, you can specify additional 
parameters to be mapped into the notififer. Example:
    
    <action name="I18N_OPENXPKI_WF_ACTION_TEST_NOTIFY1"
        class="OpenXPKI::Server::Workflow::Activity::Tools::Notify"    
        message="csr_created"
        _map_fixed_value="a fixed value"
        _map_from_context="$my_context_key">           
     </action>
     
The I<_map_> prefix is stripped, the remainder is used as key. 
Values starting with a $ sign are interpreted as context keys. 
     
# OpenXPKI::Server::Workflow::Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Rewritten by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2005-2007 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Activity;

use strict;
use base qw( Workflow::Action );

use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Server::Workflow::Pause;
use Workflow::Exception qw( workflow_error );
use Data::Dumper;

__PACKAGE__->mk_accessors( qw( resulting_state workflow ) );

sub init {
    my ( $self, $wf, $params ) = @_;
    ##! 1: 'start'
    ##! 64: 'self: ' . Dumper $self
    ##! 64: 'params: ' . Dumper $params
    ##! 64: 'wf: ' . Dumper $wf

    # FIXME - this is a bit of a hack - we're peeking into Workflow's
    # internal structures here. Workflow should provide a way to get
    # the resulting state for an activity itself.
    $self->resulting_state($wf->{_states}->{$wf->state()}->{_actions}->{$params->{name}}->{resulting_state});
    ##! 16: 'Workflow :'.ref $wf
    ##! 16: 'resulting_state: ' . $self->resulting_state()
    $self->{PKI_REALM} = CTX('session')->get_pki_realm();
    ##! 16: 'self->{PKI_REALM} = ' . $self->{PKI_REALM}

    # determine workflow's config ID
    $self->{CONFIG_ID} = CTX('api')->get_config_id({ ID => $wf->id() });
    ##! 16: 'self->{CONFIG_ID} = ' . $self->{CONFIG_ID}
    
    $self->workflow( $wf );
    
    
    # call Workflow::Action's init()
    $self->SUPER::init($wf, $params);

    ##! 1: 'end'
    return 1;
}


sub pause{
    my $self = shift;
    my ($cause, $retry_interval) = @_;
    
    #retry_interval can be modified ioa method arguments:
    $retry_interval =  $self->get_retry_intervall() if !$retry_interval;
    
    #max retries can NOT be modified ioa method arguments:
    my $max_retries = $self->get_max_allowed_retries();
    
    $cause ||= '';
    
    if($self->workflow()){
        $self->workflow()->pause($cause,$max_retries,$retry_interval);
    }
    #disrupt the execution of the run-method: 
    OpenXPKI::Server::Workflow::Pause->throw( cause => $cause);
}

sub get_max_allowed_retries{
    my $self     = shift;
    
    #manual set?
    if(defined($self->{MAX_RETRIES})){
        ##! 16: 'manual set: '.$self->{MAX_RETRIES}
        return int($self->{MAX_RETRIES});
    }
    
    #set in action-def of current workflow?
    my $val = $self->_get_wf_action_param('retry_count');
    if(defined $val){
        ##! 16: 'defined in workflow-action-xml: '.$val
        return $val;
    }
    
    #then from xml-config:
    if(defined($self->param('retry_count'))){
        ##! 16: 'defined in activity-xml: '.$self->param('retry_count')
        return $self->param('retry_count');
    }
    # TODO default setting?
    return 0;
    
}

sub set_max_allowed_retries{
    my $self     = shift;
    my $max = shift;
    $self->{MAX_RETRIES} = (defined $max)?int($max):undef;
}

sub get_reap_at_intervall{
    my $self     = shift;
    
    #manual set?
    if(defined($self->{REAP_AT_INTERVALL})){
        ##! 16: 'manual set: '.$self->{REAP_AT_INTERVALL}
        return $self->{REAP_AT_INTERVALL};
    }
    ##! 16: nothing defined, return default'
    return "+0000000005";
}

sub set_reap_at_intervall{
    my $self     = shift;
    my $intervall = shift;
    # TODO syntax validation (or sanitation), should be OpenXPKI DateTime String
    $self->{REAP_AT_INTERVALL} = (defined $intervall)?$intervall:undef;
    
    #if execution of action already has begun, the workflow has already retrieved, set and stored the reap_at timestamp
    ##! 16: sprintf('set reap at intervall to %s',$intervall)
    
    if($self->workflow() && $self->workflow()->is_running()){
        ##! 16: 'pass retry interval over to workflow!'
        $self->workflow()->set_reap_at_interval($intervall);
    }else{
         ##! 16: 'wf not running yet'
    }
}


sub get_retry_intervall{
    my $self     = shift;
    
    #manual set?
    if(defined($self->{RETRY_INTERVALL})){
        ##! 16: 'manual set: '.$self->{RETRY_INTERVALL}
        return $self->{RETRY_INTERVALL};
    }
    
    #set in action-def of current workflow?
    my $val = $self->_get_wf_action_param('retry_interval');
    if(defined $val){
        ##! 16: 'defined in workflow-action-xml: '.$val
        return $val;
    }

    #then from xml-config:
    if(defined $self->param('retry_interval' )){
        ##! 16: 'defined in activity-xml: '.$self->param('retry_interval')
        return $self->param('retry_interval');
    }
    # TODO default setting?
    ##! 16: nothing defined, return default'
    return "+0000000005";
}

sub set_retry_intervall{
    my $self     = shift;
    my $retry_intervall = shift;
    # TODO syntax validation (or sanitation), should be OpenXPKI DateTime String
    $self->{RETRY_INTERVALL} = (defined $retry_intervall)?$retry_intervall:undef;
    
    
    
}

sub wake_up{
    my $self     = shift;
    my $workflow = shift;
    ##! 1: 'wake up!'
    
}

sub resume{
    my $self     = shift;
    my ($workflow,$proc_state_resume_from) = @_;
    
    ##! 1: 'resume from '.$proc_state_resume_from
    
}

sub runtime_exception{
    my $self     = shift;
    my $workflow = shift;
    ##! 1: 'runtime_exception!'
    
}

sub _get_wf_action_param{
    my $self     = shift;
    my $key = shift;
    my $value = undef;
    
    if($self->workflow()){
        my $wf_state = $self->workflow()->_get_workflow_state();
        my $action = $wf_state->{_actions}->{$self->name};
        if(defined $action->{$key}){
            $value = $action->{$key};
        }
    }
    return $value
}

sub config_id {
    my $self = shift;
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity

=head1 Description

Base class for OpenXPKI Activities. Deriving from this class is
not mandatory, this class only provides some helper functions that
make Activity implementation easier.

=head1 Functions

=head2 init

Is called during the creation of the activity class. Initializes
$self->{CONFIG_ID}, which is the config ID of the workflow.
Also sets $self->{PKI_REALM} to CTX('session')->get_pki_realm()

Sets $self->workflow() as a reference to the current workflow.

=head2 pause

immediately ends the execution of current action. this is achieved via throwing an exception of class OpenXPKI::Server::Workflow::Pause.
before that, $self->workflow()->pause() will be called, which stores away all necessary informations.

=head2 get_max_allowed_retries

returns the number of max allowed retries (normally defined in xml-config). default: 0

=head2 set_max_allowed_retries($int)

sets the number of max allowed retries

=head2 get_retry_intervall

returns the retry intervall (relative OpenXPKI DateTime String, normally defined in xml-config). default: "+0000000005"

=head2 set_retry_intervall($string)

sets the retry intervall (relative OpenXPKI DateTime String e.g. "+0000000005")

=head2 get_reap_at_intervall

returns the reap_at intervall (relative OpenXPKI DateTime String). default: "+0000000005"

=head2 set__reap_at_intervall($string)

sets the reap_at intervall (relative OpenXPKI DateTime String, e.g. "+0000000005")

=head2 wake_up

Hook method. Will be called if Workflow::execute_action() is called after proc-state "pause". The current workflow is given as argument.

=head2 resume

Hook method. Will be called if Workflow::execute_action() is called after proc-state "exception". The current workflow is given as argument.

=head2 runtime_exception

Hook method. Will be called if Workflow::execute_action() is called with an proc-state which is not appropriate (e.g. "finished" or "running")  The current workflow is given as argument.
 
=head2 config_id

Returns the config identifier for the workflow or the current config
identifier if the config ID is not yet set (this happens in the very
first workflow activity)

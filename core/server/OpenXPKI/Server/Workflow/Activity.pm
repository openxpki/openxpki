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

sub set_retry_intervall {
    my $self     = shift;
    my $retry_intervall = shift;
    # TODO syntax validation (or sanitation), should be OpenXPKI DateTime String
    $self->{RETRY_INTERVALL} = (defined $retry_intervall)?$retry_intervall:undef;
}

sub get_retry_count {
    my $self     = shift;    
    return $self->workflow()->count_try();
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

sub setparams {
    my ($self,
	$workflow,
	$expected_params) = @_;

    # determine caller context
    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask) 
	= $self->_caller();
    my $caller_activity = $package;
    $caller_activity =~ s/^OpenXPKI::Server::Workflow::Activity:://;

    # export canonical activity name to caller activity (for convenience)
    ### activity: $caller_activity
    $self->param('activity' => $caller_activity);

    # check that we were passed a hash ref
    if (! defined $expected_params ||
	(ref $expected_params ne "HASH")) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_INVALID_ARGUMENT",
	    params  => { 
		"CALLERPACKAGE" => $package,
		"FILENAME"      => $filename,
		"LINE"          => $line,
	    });
    }

    my $context = $workflow->context();
    my $log = get_logger(); 

    # examine context parameters
    foreach my $field (keys %{$expected_params}) {
	# TODO: sanity check, make sure that we have scalar in $field
	
	### field: $field
	my @sources = qw( config default );
	
	if (exists $expected_params->{$field}->{accept_from}) {
	    @sources = @{$expected_params->{$field}->{accept_from}};
	}

	### sources: @sources

	my $value;
	my $found = 0;
      CHECKSOURCE:
	foreach my $source (@sources) {
	    ### checking source: $source
	    if ($source eq 'context') {
		my $tmp = $context->param($field);
		if (defined $tmp) {
		    $value = $tmp;
		    $found = 1;
		    ### found value: $value
		    last CHECKSOURCE;
		}
	    }
	    if ($source eq 'config') {
		my $tmp = $self->param($field);
		if (defined $tmp) {
		    $value = $tmp;
		    $found = 1;
		    ### found value: $value
		    last CHECKSOURCE;
		}
	    }
	    if ($source eq 'default') {
		my $tmp = $expected_params->{$field}->{default};
		if (defined $tmp) {
		    $value = $tmp;
		    $found = 1;
		    ### found value: $value
		    last CHECKSOURCE;
		}
	    }
	}
	
	### ... check parameters demanded by class implementation
	if (! $found && $expected_params->{$field}->{required}) {
	    # throw exception if mandatory parameter is not available
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_MISSING_CONTEXT_PARAMETER",
		params  => { 
		    PARAMETER     => $field,
		    SOURCES       => @sources,
		    CALLERPACKAGE => $package,
		    ACTIVITY      => $context->param('activity'),
		});
	}
	
	# Make parameter available in activity
	# NOTE: overriding an already existing value is done voluntarily
	# even if it is undef (see docs).
        # Work around a bug in Workflow::Base::param() that does not 
	# allow to set reset a single parameter. It works when called 
	# with a hash ref, though.
        $self->param({ $field => $value });
        $log->debug("Value for '$field' : ", $self->param($field));
    } 
}


# get caller activity (not THIS package, but the actual activity)
sub _caller {
    my ($self) = @_;

    my $level = 0;
    my @caller = caller($level);

    while ($caller[0] eq "OpenXPKI::Server::Workflow::Activity") {
	$level++;
	@caller = caller($level);
    }
    return @caller;
}



1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity

=head1 Description

Base class for OpenXPKI Activities. Deriving from this class is
mandatory if you use the extended flow control features.

=head2 Configuration parameters

To use the flow control features, you can set several parameters in the
workflow configuration. The retry params can be set in either the activity 
or in the state block. If both are given, those in the state block are 
superior. The autofail parameter is allowed only in the state block.  

=over

=item retry_count

Integer value, how many times the system will redo the action after pause is called.
If the given value is exceeded, the action stops with an error state. 

=item retry_interval (default 5 minutes)

The amount of time to sleep after pause is called, before a new retry is done.
The value needs to be parsable as a relative OpenXPKI DateTime string.
Note that this is a minimum amount of time that needs to elapse, after which 
the watchdog is allowed to pick up the job. Depending on your load and watchdog
settings, the actual time can be much greater! 

=item autofail      

If set to "yes", the workflow is moved directly to the FAILURE state and
set to finished in case of an error. This also affects a retry_exceeded
situation!
    
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

=head2 set_reap_at_intervall($string)

sets the reap_at intervall (relative OpenXPKI DateTime String, e.g. "+0000000005")

=head2 get_retry_count

Return the value of the retry counter.

=head2 wake_up

Hook method. Will be called if Workflow::execute_action() is called after proc-state "pause". The current workflow is given as argument.

=head2 resume

Hook method. Will be called if Workflow::execute_action() is called after proc-state "exception" or "retry_exceeded". 
The current workflow is given as first argument, the process state to recover from as second.

=head2 runtime_exception

Hook method. Will be called if Workflow::execute_action() is called with an proc-state which is not appropriate (e.g. "finished" or "running")  The current workflow is given as argument.
 
=head2 config_id

Returns the config identifier for the workflow or the current config
identifier if the config ID is not yet set (this happens in the very
first workflow activity)


=head2 Setting parameters

Activity parameters can stem from three sources:

=over 4

=item * 

Default values defined in the Activity implementation Perl code itself

=item * 

Parameters configured in the Activity XML configuration file for the
particular Activity.

=item * 

Parameters passed in via the Workflow Context

=back

These sources are ordered with descending trust level.
A default value configured in the source code should
always be considered trusted. A value in the configuration file is
at least specified or reviewed by authorized persons who specify the 
system behaviour.
However, a  parameter that is passed via the Workflow Context 
is potentially user specified input which may inflict security problems.

The Activity implementation MUST take care or proper handling whenever
untrusted user input (from the Workflow Context) is processeed.

It is recommended that the Activity implementation code processes, prepares,
and validates all parameters before doing anything else. To assist the
implementer in this task it is recommended to specify expected 
parameter name, possible sources and possible defaults via setparams().


=head2 setparams ( $workflow, \%expected_params )

Checks Activity parameters (from Activity XML configuration) and context 
passed by caller for required and optional parameters and copies the 
named parameters to the Activity parameters. 

Modifies Activity parameters (accessible via $self->param(...) within
the code). Does NOT modify the context itself!

The method expects the current workflow instance as first parameter.
The second parameter must be a hash reference that contains the expected
fields as keys.

The corresponding values are again hash references that include a description
if the key parameter is optional, required or should be assigned a default
value if unset.
If a required parameter is not found in the context the method throws
an exception.
After the function returns the caller can access copies of all 
parameters that are referenced in the parameter definition
via its own parameters ($self->param(...)). This includes parameters
passed in from the context if this was allowed explicitly.

Implementers MUST make sure that untrusted user input is validated properly.


The hash reference members are hash references with three possible keys:

  accept_from => <arrayref>
  default => <any Perl data structure>
  required => integer

=over 4

=item * 

The C<accept_from> value is an array ref that names the possible 
sources for the parameter value. Allowed values in this list are 
'context', 'config' and 'default'. Unknown sources are ignored. If
a parameter value is defined in the specified source, this value is 
accepted. If the specified source does not contain the named parameter
the search continues until the end of the list is reached. If no
source contained a suitable value, the parameter will be set to
undef.

If C<accept_from> is not specified, it defaults to [ 'config', 'default' ].

=item * 

The C<default> value is the value that should be assigned to the
parameter if the source 'default' is quieried.

=item * 

If C<required> is set to a true value and the parameter could not
be determined from the specified sources the method throws an
C<I18N_OPENXPKI_WORKFLOW_ACTIVITY_MISSING_PARAMETER> exception.

=back

The hash reference must be constructed as follows:

  {
    # If 'some_parameter' is specified in the context, use it. otherwise
    # use the value specified in the activity configuration. if neither
    # is available, use the default value 'abc123'.
    # $self->param('some_parameter') will always return a defined value
    # after this check has been processed.
    some_parameter => {
      accept_from => [ 'context', 'config', 'default' ],
      default => "abc123",
    },

    # 'protected_parameter' is ignored if it is present in the Context.
    # If specified in the XML config, $self->param('protected_parameter')
    # will return the value defined there. Otherwise it will return 
    # 'abc456'.
    protected_parameter => {
      accept_from => [ 'config', 'default' ],
      default => "abc456",
    },

    # identical to 'protected_parameter': [ 'config', 'default' ] is the
    # default for accept_from.
    protected_parameter2 => {
      default => "abc456",
    },

    # $self->param('user_parameter') will return the value specified 
    # in the context if it is present there. Otherwise it will return 
    # the default value.
    user_parameter => {
      accept_from => [ 'context', 'default' ],
      default => "abc123",
    },

    # $self->param('weird_parameter') is taken from the configuration 
    # file.
    # If it is NOT specified there, the corresponding context value is
    # used instead. If neither exist, an exception is thrown.
    weird_parameter => {
      accept_from => [ 'config', 'context' ],
      required => 1,
    },

    # $self->param('cleared_parameter') is always undefined, even if it
    # was specified in the configuration or in the context. Not very 
    # useful but possible...
    cleared_parameter => {
      accept_from => [ ],
    },
  }


=head3 Example

Caller example as seen from the Activity implementation:

  ...
  use base qw( OpenXPKI::Server::Workflow::Activity );
  ...
  sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->setparams($workflow, 
		     {
			keytype => {
                            accept_from => [ 'context', 'default' ],
			    default => 'RSA',
			},
			keypass => {
                            accept_from => [ 'context' ],
			},
			_token => {
                            accept_from => [ 'context' ],
			    required => 1,
			},
		    });

  ...
  # later in the Activity implementation you can reference the
  # local parameter
  my $keytype = $self->param('keytype');
  ...

In this case the setparams() function will throw a 'missing context 
parameter' exception if the required '_token' parameter was not found 
in the context.
If no 'keytype' parameter was found, it will set the default 'RSA'.
The 'keypass' parameter is optional in this case and will simply be
copied to the Activity parameters.

=head3 Activity configuration example

In this definition the parameter C<tokentype> is set to "DEFAULT":

  <action name="token.default.get"
	  class="OpenXPKI::Server::Workflow::Activity::Token::Get"
	  tokentype="DEFAULT">
    <description>Instantiate a default crypto token</description>
  </action>


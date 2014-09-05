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

__PACKAGE__->mk_accessors( qw( resulting_state workflow _map ) );

sub init {
    my ( $self, $wf, $params ) = @_;
    ##! 1: 'start ' . $params->{name}
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

    $self->workflow( $wf );


    # copy the source params
    my $params_merged = { % { $params }};

    # init the _map parameters
    my $_map = {};

    foreach my $key (keys %{$params}) {
        if ($key !~ /^_map_(.*)/) { next; }

        # Remove map key from the hash
        delete $params_merged->{$key};

        my $name = $1;
        my $val = $params->{$key};
        $_map->{$name} = $params->{$key};
        ##! 8: 'Found param ' . $name . ' - value : ' . $params->{$key}

##=cut disabled-by-oli
##
##        if ($val =~ /^\$(\S+)/) {
##            # copy from context
##            $_map->{$name} = ['ctx', $1];
##
##        } else { # }if ($val =~ /^\&(\S+)/) {
##            # TT parser
##            $_map->{$name} = ['tt', $val ];
##        #} else {
##        #
##        #    # static value, add to plain params hash
##        #    $params_merged->{$name} = $val;
##        }
##
##=cut disabled-by-oli

    }

    # call Workflow::Action's init()
    $self->SUPER::init($wf, $params_merged);

    $self->_map( $_map );

    ##! 32: 'merged params ' . Dumper  $params_merged
    ##! 32: 'map ' . Dumper  $_map

    ##! 1: 'end'
    return 1;
}


sub pause{
    my $self = shift;
    my ($cause, $retry_interval) = @_;

    # retry_interval can be modified via method arguments:
    $retry_interval =  $self->get_retry_intervall() if !$retry_interval;

    # max retries can NOT be modified via method arguments:
    my $max_retries = $self->get_max_allowed_retries();

    $cause ||= '';

    if($self->workflow()){
        # Workflow expects explicit wakeup as epoch
        my $dt_wakeup_at = OpenXPKI::DateTime::get_validity({
            VALIDITY => $retry_interval,
            VALIDITYFORMAT => 'detect',
        });

        $self->workflow()->pause($cause, $max_retries, $dt_wakeup_at->epoch() );
    }
    # disrupt the execution of the run-method:
    OpenXPKI::Server::Workflow::Pause->throw( cause => $cause);
}


sub param {

    my ( $self, $name, $value ) = @_;

    unless ( defined $name ) {
        my $result = { %{ $self->{PARAMS} } };

        # add mapped params
        my $map = $self->_map();
        foreach my $key (keys %{ $map }) {
            $result->{$key} = $self->param( $key );
        }
        return $result;
    }

    # set requests are pushed upstream
    if ( ref $name ne '' || defined $value ) {
        return $self->SUPER::param( $name, $value );
    }

    if ( exists $self->{PARAMS}{$name} ) {
        return $self->{PARAMS}{$name};
    } else {
        my $map = $self->_map();
        return undef unless ($map->{$name});
        ##! 16: 'query for mapped key ' . $name

        my $template = $map->{$name};
        # shortcut for single context value
        if ($template =~ /^\$(\S+)/) {
            my $ctxkey = $1;
            ##! 16: 'load from context ' . $ctxkey
            my $ctx = $self->workflow()->context()->param( $ctxkey );
            if ($ctx =~ m{ \A HASH | \A ARRAY }xms) {
                ##! 32: ' needs deserialize '
                my $ser  = OpenXPKI::Serialization::Simple->new();
                return $ser->deserialize( $ctx );
            } else {
                return $ctx;
            }
        } else {
            ##! 16: 'parse using tt ' . $map->{$name}->[1]
            my $tt = Template->new();
            my $out;
            if (!$tt->process( \$template, { context => $self->workflow()->context()->param() }, \$out )) {
                OpenXPKI::Exception->throw({
                    MESSAGE => 'I18N_OPENXPKI_SERVER_ACTIVITY_ERROR_PARSING_TEMPLATE_FOR_PARAM',
                    PARAMS => {
                        'TEMPLATE' => $template,
                        'PARAM'  => $name,
                        'ERROR' => $tt->error()
                    }
                });
            }
            ##! 32: 'tt result ' . $out
            return $out;
        }
    }
    return undef;
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

=back

=head1 Functions

=head2 init

Is called during the creation of the activity class.
Sets $self->{PKI_REALM} to CTX('session')->get_pki_realm()

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

=head1 Parameter mapping

Parameters in the xml configuration of the activity that start with I<_map_>
are parsed using template toolkit and imported into the namespace of the
action class.

The prefix is stripped and the param is set to the result of the evaluation,
the value is interpreted as template and filled with the context:

  <action name=".." class="..."
   _map_my_tt_param="my_prefix_[% context.my_context_key %]>

If you just need a single context value, the dollar sign is a shortcut:

  <action name=".." class="..."
    _map_my_simple_param="$my_context_key">

The values are accessible thru the $self->param call using the basename.

=head3 Activity configuration example

If C<my_context_key> has a value of foo in the context, this configuration:

  <action name="..." class="..."
   _map_my_simple_param="$my_context_key"
   _map_my_tt_param="my_prefix_[% context.my_context_key %]">
  </action>

Is the same as:

  <action name="..." class="..."
   my_simple_param="foo"
   my_tt_param="my_prefix_foo">
  </action>




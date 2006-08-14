# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity;

use strict;
use base qw( Workflow::Action );
use Log::Log4perl       qw( get_logger );

#use Smart::Comments;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;


sub execute {
    my ($self, 
	$workflow, 
	$params) = @_;

    # check workflow context for parameters and import them to activity
    # parameters
    $self->setparams($workflow, $params->{PARAMS});

    # activity class (role), defaults to "CA"
    my $activityclass 
	= exists $params->{ACTIVITYCLASS} 
          ? $params->{ACTIVITYCLASS}
          : "CA";

    # mbartosch
    # FIXME: add call to authorization module
    # my $authorized = CTX('authorization')->authorize(
    #                      ACTIVITYCLASS => $activityclass,
    #                      ACTIVITY      => $self->{ACTIVITY},
    #                      # original creator of this workflow instance
    #                      CREATOR       => $workflow->context()->param('creator'),
    #                      # current user who executes this particular activity
    #                      USER          => $workflow->context()->param('user'),
    #                  );
    #
    # if (! $authorized)
    # {
    #     OpenXPKI::Exception->throw (
    #         message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_AUTHORIZATION_FAILED",
    #         params  => { 
    #             ACTIVITYCLASS => $activityclass,
    #             ACTIVITY      => $self->{ACTIVITY},
    #             USER          => $workflow->context()->param('user'),
    #         }
    #     );
    # }

    # FIXME: this is fully senseless because activities has not to inherit from this activity
    # bellmich
    # added authorization call
    # FIXME: we can only support on operation. Please choose:
    # FIXME:   1. ACTIVITYCLASS
    # FIXME:   2. ACTIVITY
    #    ACTIVITYCLASS => $activityclass,
    CTX('acl')->authorize ({
        ACTIVITY      => $self->{ACTIVITY},
        AFFECTED_ROLE => $workflow->context()->param('role')});

    return 1;
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
    $self->{ACTIVITY} = $caller_activity;

    # export session to caller activity
    $self->{SESSION} = CTX('session');
    if (! defined $self->{SESSION}) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_INVALID_SESSION",
	    params  => { 
		"CALLERPACKAGE" => $package,
		"FILENAME"      => $filename,
		"LINE"          => $line,
	    },
            );
    }

    # export PKI realm to caller activity
    $self->{PKI_REALM} = $self->{SESSION}->get_pki_realm();
    if (! defined $self->{PKI_REALM}) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_PKI_REALM_UNDEFINED",
	    params  => { 
		"CALLERPACKAGE" => $package,
		"FILENAME"      => $filename,
		"LINE"          => $line,
	    },
            );
    }
    
    $self->{TOKEN}->{DEFAULT} = CTX('pki_realm')->{$self->{PKI_REALM}}->{crypto}->{default};
    if (! defined $self->{TOKEN}->{DEFAULT}) {
	OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_DEFAULT_TOKEN_UNAVAILABLE",
	    params  => { 
		"CALLERPACKAGE" => $package,
		"FILENAME"      => $filename,
		"LINE"          => $line,
	    },
            );
    }

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
not mandatory, this class only provides some helper functions that
make Activity implementation easier.

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


=head2 Subclassing

Derived classes should call the execute() method of this class.


=head1 Functions

=head2 execute

The execute() method wraps the Activity execution and provides a framework
that derived classes (i. e. actual Workflow Activities) can use to 
consistently interface with the OpenXPKI system.



=head2 setparams ( $workflow, \%expected_params )

Checks Activity parameters (from Activity XML configuration) and context 
passed by caller for required and optional parameters and copies the 
named parameters to the Activity parameters. 

Modifies Activity parameters (accessible via $self->param(...) within
the code). Does NOT modify the context itself!

For convenience, the calling activity can rely on being able to 
access the following internal settings that are read from the server 
context:

=over 4

=item * 

The current activity name via
  $self->{ACTIVITY}

=item * 

The current session via
  $self->{SESSION}

=item * 

The current PKI realm name via
  $self->{PKI_REALM}

=item * 

A usable default token via
  $self->{TOKEN}->{DEFAULT}

=back

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



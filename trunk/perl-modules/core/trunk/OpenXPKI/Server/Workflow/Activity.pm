# OpenXPKI Workflow Activity
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity;

use strict;
use base qw( Workflow::Action );
use Log::Log4perl       qw( get_logger );

# use Smart::Comments;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;


sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $params   = shift;

    # check workflow context for parameters and import them to activity
    # parameters
    $self->setparams($workflow, $params->{PARAMS});

    # activity class (role), defaults to "CA"
    my $activityclass 
	= exists $params->{ACTIVITYCLASS} 
          ? $params->{ACTIVITYCLASS}
          : "CA";

    my $authorized = 1;
    # FIXME: add call to authorization module
#     my $authorized = CTX('authorization')->authorize(
# 	ACTIVITYCLASS => $activityclass,
# 	ACTIVITY      => $self->param('activity'),
# 	# original creator of this workflow instance
# 	CREATOR       => $workflow->context()->param('creator'),
# 	# current user who executes this particular activity
# 	USER          => $workflow->context()->param('user'),
# 	);

    if (! $authorized) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_AUTHORIZATION_FAILED",
	    params  => { 
		ACTIVITYCLASS => $activityclass,
		ACTIVITY      => $self->param('activity'),
		USER          => $workflow->context()->param('user'),
	    });
    }

    return 1;
}


sub setparams {
    my $self = shift;
    my $workflow = shift;
    my $expected_params = shift;

    # determine caller context
    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask) 
	= $self->_caller();
    my $caller_activity = $package;
    $caller_activity =~ s/^OpenXPKI::Server::Workflow::Activity:://;

    # export canonical activity name to caller activity (for convenience)
    $self->param('activity' => $caller_activity);

    # no parameters: nothing to do
    return if (! defined $expected_params);

    # check that we were passed a hash ref
    if (ref $expected_params ne "HASH") {
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
	my $value = $context->param($field);

	if (! defined $value) {
	    # throw exception if mandatory parameter is not available
	    if ($expected_params->{$field}->{required}) {

		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_WORKFLOW_ACTIVITY_MISSING_CONTEXT_PARAMETER",
		    params  => { 
			"PARAMETER"     => $field,
			"CALLERPACKAGE" => $package,
			"ACTIVITY"      => $context->param('activity'),
		    });
	    }

	    # assign default value if available
	    $value = $expected_params->{$field}->{default};
	}

	# make parameter available in activity
        $self->param($field, $value);
        $log->debug("Value for '$field' : ", $self->param($field));
    } 
}


# get caller activity (not THIS package, but the actual activity)
sub _caller {
    my $self = shift;

    my $level = 0;
    my @caller = caller($level);

    while ($caller[0] eq "OpenXPKI::Server::Workflow::Activity") {
	$level++;
	@caller = caller($level);
    }
    return @caller;
}

1;

=head1 Description

Base class for OpenXPKI Activities. Deriving from this class is
not mandatory, this class only provides some helper functions that
make activity implementation easier.

=head2 Subclassing

Derived classes should call the execute() method of this class.


=head1 Functions

=head2 execute

The execute() method wraps the activity execution and provides a framework
that derived classes (i. e. actual Workflow Activities) can use to 
consistently interface with the OpenXPKI system.



=head2 setparams ( $workflow, \%expected_params )

Checks context for required and optional parameters and copies the
named parameters to the activity parameters. Does NOT modify the context
itself!

This method expects the current workflow instance as first parameter.
The second parameter must be a hash reference that contains the expected
context fields as keys.
Corresponding values are again hash references that include a description
if the key parameter is optional, required or should be assigned a default
value if unset.
If a required parameter is not found in the context the method throws
an exception.
After the function returns the caller can access copies of all 
context parameters that are referenced in the parameter definition
via its own parameters ($self->param(...))

=head3 Example

Caller example as seen from the activity implementation:

  ...
  use base qw( OpenXPKI::Server::Workflow::Activity );
  ...
  sub execute {
    my $self = shift;
    my $workflow = shift;

    $self->setparams($workflow, 
		     {
			keytype => {
			    default => 'RSA',
			},
			keypass => {
			},
			token => {
			    required => 1,
			},
		    });

  ...
  # later in the activity implementation you can reference the
  # local parameter
  my $keytype = $self->param('keytype');
  ...

In this case the setparams() function will throw a 'missing context 
parameter' exception if the required 'token' parameter was not found 
in the context.
If no 'keytype' parameter was found, it will set the default 'RSA'.
Note that the context will NOT be modified if defaults are applied!
The 'keypass' parameter is optional in this case and will simply be
copied to the activity parameters.


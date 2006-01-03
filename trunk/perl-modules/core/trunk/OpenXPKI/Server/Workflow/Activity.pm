# OpenXPKI Workflow Activity
# Copyright (c) 2005 Martin Bartosch
# $Revision: 80 $

package OpenXPKI::Server::Workflow::Activity;

use strict;
use base qw( Workflow::Action );
use Log::Log4perl       qw( get_logger );

#use Workflow::Factory;
use OpenXPKI::Exception;


sub setparams {
    my $self = shift;
    my $workflow = shift;
    my $expected_params = shift;

    # determine caller context
    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask) 
	= caller(0);
    my $caller_activity = $package;
    $caller_activity =~ s/^OpenXPKI::Server::Workflow::Activity:://;

    # export canonical activity name to caller activity (for convenience)
    $self->param('activity' => $caller_activity);
    
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
			"ACTIVITY"      => $caller_activity,
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


1;

=head1 Description

Base class for OpenXPKI Activities. Deriving from this class is
not mandatory, this class only provides some helper functions that
make activity implementation easier.

=head1 Functions

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


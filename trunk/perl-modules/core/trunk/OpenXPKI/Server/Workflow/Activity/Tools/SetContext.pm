# OpenXPKI::Server::Workflow::Activity::Tools::SetContext
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::SetContext;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use English;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    ##! 16: 'SetContext'

    my %options = (
	overwritecontext => 0,
	extendedsyntax   => 0,
	);

    my $parameters = $self->param('SetContextParameters');
    foreach my $entry (split /,\s*/, $parameters) {
	my ($bool, $entry) = ($entry =~ m{ \A (!?)(.*) \z }xms);
	$bool = 0 + ($bool ne '!');
	$options{$entry} = $bool;
    }
    ##! 16: 'options: ' . Dumper \%options
    ##! 16: ' parameters: ' . Dumper $self->{PARAMS}
  KEY:
    foreach my $key (%{$self->{PARAMS}}) {
	next KEY if ($key eq 'SetContextParameters');
	my $value = $self->param($key);

	# execute configured value in current context. since $value comes
	# only from the configured parameters ($self->param) instead of the
	# context, this is safe as long as the configuration file is not
	# compromised.
	if ($options{extendedsyntax}) {
	    $value = eval $value;

	    if ($EVAL_ERROR) {
		OpenXPKI::Exception->throw(
		    message =>
		    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_SETCONTEXT_INVALID_EXTENDED_SYNTAX',
		    params => {
			EVAL_ERROR => $EVAL_ERROR,
		    },
		    log => {
			logger   => CTX('log'),
			priority => 'error',
			facility => 'system',
		    },
		    );
	    }
	    # allow anonymous subroutines in configuration
	    if (ref $value eq 'CODE') {
		eval {
		    $value = &{$value}($workflow);
		};
		if ($EVAL_ERROR) {
		    OpenXPKI::Exception->throw(
			message =>
			'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_SETCONTEXT_INVALID_EXTENDED_SYNTAX_CODEREF',
			params => {
			    EVAL_ERROR => $EVAL_ERROR,
			},
			log => {
			    logger   => CTX('log'),
			    priority => 'error',
			    facility => 'system',
			},
			);
		}
	    }
	}
	
	my $old = $context->param($key);
	if (! defined $old) {
	    ##! 16: "setting context $key: $value"
	    $context->param($key => $value);
	} else {
	    if ($options{overwritecontext}) {
		##! 16: "overwriting context $key: $value"
		$context->param($key => $value);
	    }
	}
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::SetContext

=head1 Description

Set context parameters from the activity definition.

This allows to explicitly set workflow context parameters from the XML
configuration of this activity.

Option parameter (set in action definition):
SetContextParameters   - comma separated list of options

Possible values:
!overwritecontext   (DEFAULT) Keep original context value if it exists
overwritecontext              Overwrite context value

!extendedsyntax     (DEFAULT) Standard behaviour
extendedsyntax                Configured values are evaluated as perl code
                              (see below).

=head1 Extended Syntax

If the extendedsyntax option is set, the configured values are evaluated
as Perl
                              Allows access to internal data structures,
                              most prominently the workflow context via
                              the $context variable.
                              NOTE: use with caution, improper use may cause
                              security problems.

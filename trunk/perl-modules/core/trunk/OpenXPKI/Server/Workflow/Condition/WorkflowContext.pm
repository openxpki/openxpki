# OpenXPKI::Server::Workflow::Condition::WorkflowContext
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::WorkflowContext;

use strict;
use warnings;
use base qw( Workflow::Condition );
use DateTime;
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;
use OpenXPKI::Exception;
use Data::Dumper;


my @parameters = qw(
    context_key
    context_value
    condition
);

__PACKAGE__->mk_accessors(@parameters);

sub _init
{
    my ( $self, $params ) = @_;

    # propagate workflow condition parametrisation to our object
    foreach my $arg (@parameters) {
	if (defined $params->{$arg}) {
	    $self->$arg( $params->{$arg} );
	}
    }
    if (! (defined $self->context_key() && defined $self->condition())) {
	##! 16: 'error: no conditions defined'
	configuration_error
	    "Missing parameters in ",
	    "declaration of condition ", $self->name;
    }
}

sub evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();
    my $pki_realm   = CTX('session')->get_pki_realm();

    foreach my $arg (@parameters) {
	# access workflow context instead of literal value if value starts
	# with a $
	if (defined $self->$arg() && ($self->$arg() =~ m{ \A \$ (.*) }xms)) {
	    my $wf_key = $1;
	    $self->$arg( $context->param($wf_key) )
	}
	##! 64: 'param: ' . $arg . '; value: ' . $self->$arg()
    }

    my $context_key = $self->context_key();
    my $condition = $self->condition();

    if ($condition eq 'exists') {
	my $context_value = $context->param($context_key);
	if (! defined $context_value) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCONTEXT_CONTEXT_VALUE_DOES_NOT_EXIST';
	}
    } elsif ($condition eq 'notnull') {
	my $context_value = $context->param($context_key);
	if (! defined $context_value || ($context_value eq '')) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCONTEXT_CONTEXT_VALUE_EMPTY';
	}
    } elsif ($condition eq 'equals') {
	my $context_value = $context->param($context_key);
	if ($context_value ne $self->context_value()) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCONTEXT_CONTEXT_EQUALITY_MISMATCH';
	}
    } elsif ($condition eq 'regex') {
	my $context_value = $context->param($context_key);
	my $regex = qr/$self->context_value()/ms;
	if ($context_value =~ /$regex/) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCONTEXT_CONTEXT_REGEX_MISMATCH';
	}
    } else {
	condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_WORKFLOWCONTEXT_INVALID_CONDITION';
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::WorkflowContext

=head1 SYNOPSIS
  <condition 
     name="private_key_not_empty" 
     class="OpenXPKI::Server::Workflow::Condition::WorkflowContext">
    <param name="context_key" value="private_key"/>
    <param name="condition" value="exists"/>
  </condition>

  <condition 
     name="profile_contains_encryption" 
     class="OpenXPKI::Server::Workflow::Condition::WorkflowContext">
    <param name="context_key" value="cert_profile"/>
    <param name="condition" value="regex"/>
    <param name="context_value" value=".*ENCRYPTION.*"/>
  </condition>

=head1 DESCRIPTION

Checks if the specified context entry exists, is not empty or matches
a given string or regex.

Parameters:

context_key:            checks are applied to this context key
condition:              type of check: 'exists', 'notnull', 'regex', 'equals'
context_value:          comparison value for regex or equals check

Note: if parameters specified start with a '$', the corresponding workflow
context parameter is referenced instead of the literal string.


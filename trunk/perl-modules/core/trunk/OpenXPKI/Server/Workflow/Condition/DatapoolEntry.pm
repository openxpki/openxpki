# OpenXPKI::Server::Workflow::Condition::DatapoolEntry
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::DatapoolEntry;

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
    datapool_namespace
    datapool_key
    datapool_value
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
    if (! (defined $self->datapool_namespace()
	   && defined $self->datapool_key() 
	   && defined $self->condition())) {
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

    my $params      = { 
	PKI_REALM => CTX('session')->get_pki_realm(),
    };

    foreach my $arg (@parameters) {
	# access workflow context instead of literal value if value starts
	# with a $
	if (defined $self->$arg() && ($self->$arg() =~ m{ \A \$ (.*) }xms)) {
	    my $wf_key = $1;
	    $self->$arg( $context->param($wf_key) )
	}
	##! 64: 'param: ' . $arg . '; value: ' . $self->$arg()
    }

    my $condition = $self->condition();

    $params->{NAMESPACE} = $self->datapool_namespace();
    $params->{KEY}       = $self->datapool_key();

    my $msg = CTX('api')->get_data_pool_entry($params);

    my $datapool_value = $msg->{VALUE};

    if ($condition eq 'exists') {
	if (! defined $datapool_value) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_DOES_NOT_EXIST';
	}
    } elsif ($condition eq 'notnull') {
	if (! defined $datapool_value || ($datapool_value eq '')) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_VALUE_EMPTY';
	}
    } elsif ($condition eq 'equals') {
	if ($datapool_value ne $self->datapool_value()) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_EQUALITY_MISMATCH';
	}
    } elsif ($condition eq 'regex') {
	my $regex = qr/$self->datapool_value()/ms;
	if ($datapool_value =~ /$regex/) {
	    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOL_REGEX_MISMATCH';
	}
    } else {
	condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_INVALID_CONDITION';
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::DatapoolEntry

=head1 SYNOPSIS
  <condition 
     name="private_key_not_empty" 
     class="OpenXPKI::Server::Workflow::Condition::DatapoolEntry">
    <param name="datapool_key" value="$cert_identifier"/>
    <param name="datapool_namespace" value="certificate.privatekey"/>
    <param name="condition" value="exists"/>
  </condition>

=head1 DESCRIPTION

Checks if the specified datapool entry exists, is not empty or matches
a given string or regex.

Parameters:

datapool_namespace:     check entries in this namespace (required)
datapool_key:           checks are applied to this datapool entry
condition:              type of check: 'exists', 'notnull', 'regex', 'equals'
datapool_value:         comparison value for regex or equals check

Note: if parameters specified start with a '$', the corresponding workflow
context parameter is referenced instead of the literal string.


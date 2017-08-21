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

    my $ds_params      = {
    PKI_REALM => CTX('session')->data->pki_realm,
    };

    my $params = {};
    foreach my $arg (@parameters) {
    # access workflow context instead of literal value if value starts
    # with a $
    if (defined $self->$arg() && ($self->$arg() =~ m{ \A \$ (.*) }xms)) {
        my $wf_key = $1;
        ##! 32: ' Set Identifier ' . $wf_key . ' - ' . $context->param($wf_key)
        $params->{$arg} = $context->param($wf_key);
    } else {
        $params->{$arg} = $self->$arg();
    }
    ##! 64: 'param: ' . $arg . '; value: ' . $params->{$arg}
    }

    my $condition = $params->{condition};

    $ds_params->{NAMESPACE} = $params->{datapool_namespace};
    $ds_params->{KEY}       = $params->{datapool_key};

    ##! 32: 'Query params ' . Dumper $ds_params

    my $msg = CTX('api')->get_data_pool_entry($ds_params);

    ##! 32: 'api returned ' . Dumper $msg

    my $datapool_value = $msg->{VALUE};

    if ($condition eq 'exists') {
    if (! defined $datapool_value) {
        ##! 64: ' value not exist'
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_DOES_NOT_EXIST';
    }
    } elsif ($condition eq 'notnull') {
    if (! defined $datapool_value || ($datapool_value eq '')) {
        ##! 64: ' value empty'
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_VALUE_EMPTY';
    }
    } elsif ($condition eq 'equals') {
    if ($datapool_value ne $params->{datapool_value}) {
        ##! 64: ' value equality mismatch '
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_EQUALITY_MISMATCH';
    }
    } elsif ($condition eq 'regex') {
    my $regex = qr/$params->{datapool_value}/ms;
    if ($datapool_value =~ /$regex/) {
        ##! 64: ' value regex mismatch '
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOL_REGEX_MISMATCH';
    }
    } else {
        ##! 64: ' invalid condition '
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


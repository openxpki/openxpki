# OpenXPKI::Server::Workflow::Condition::DatapoolEntry
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::DatapoolEntry;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Condition );
use DateTime;
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;
use Data::Dumper;

sub _evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();

    my $condition = $self->param('condition');

    my $params = {
        namespace => $self->param('namespace'),
        key => $self->param('key'),
    };

    if (!$params->{namespace}) {
        configuration_error('Datapool::GetEntry requires the namespace parameter');
    }
    if (!$params->{key}) {
        configuration_error('Datapool::GetEntry requires the key parameter');
    }

    if ($self->param('pki_realm')) {
        if ($self->param('pki_realm') eq '_global') {
            $params->{pki_realm} = '_global';
        } elsif($self->param('pki_realm') ne CTX('session')->data->pki_realm) {
            workflow_error( 'Access to foreign realm is not allowed' );
        }
    }

    ##! 32: 'Query params ' . Dumper $ds_params

    my $msg = CTX('api2')->get_data_pool_entry(%$params);

    ##! 32: 'api returned ' . Dumper $msg

    my $datapool_value = $msg->{value};

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
        if ($datapool_value ne $self->param('value')) {
            ##! 64: ' value equality mismatch '
            condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_DATAPOOLENTRY_EQUALITY_MISMATCH';
        }
    } elsif ($condition eq 'regex') {
        my $val = $self->param('value');
        my $regex = qr/$val/ms;
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
    private_key_not_empty:
        class: OpenXPKI::Server::Workflow::Condition::DatapoolEntry
        param:
            _map_key: $cert_identifier
            namespace: certificate.privatekey
            condition: exists

=head1 DESCRIPTION

Checks if the specified datapool entry exists, is not empty or matches
a given string or regex.

Parameters:

namespace:     check entries in this namespace (required)
key:           checks are applied to this datapool entry
condition:     type of check: 'exists', 'notnull', 'regex', 'equals'
value:         comparison value for regex or equals check


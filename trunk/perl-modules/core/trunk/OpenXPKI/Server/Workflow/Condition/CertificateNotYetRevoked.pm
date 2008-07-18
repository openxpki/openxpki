# OpenXPKI::Server::Workflow::Condition::CertificateNotYetRevoked
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::CertificateNotYetRevoked;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Debug;
use English;
use OpenXPKI::Exception;

__PACKAGE__->mk_accessors( 'crl_issuance_pending_accept' );

sub _init
{
    my ( $self, $params ) = @_;
    unless ( $params->{'crl_issuance_pending_accept'} )
    {
        configuration_error
             "You must define one value for 'crl_issuance_pending_accept' in ",
             "declaration of condition ", $self->name;
    }
    $self->crl_issuance_pending_accept($params->{'crl_issuance_pending_accept'});
}
sub evaluate
{
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();
    my $identifier  = $context->param('cert_identifier');
    my $reason_code = $context->param('reason_code');
    my $pki_realm   = CTX('session')->get_pki_realm();

    if (! defined $identifier) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_IDENTIFIER_MISSING',
        );
    }
    CTX('dbi_backend')->commit();
    my $cert = CTX('dbi_backend')->first(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'STATUS',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $identifier,
            'PKI_REALM'  => $pki_realm,
        }
    );
    ##! 16: 'status: ' . $cert->{'STATUS'}
    if (! $self->crl_issuance_pending_accept()
        && $cert->{'STATUS'} eq 'CRL_ISSUANCE_PENDING') {
        # certificate is in state 'CRL_ISSUANCE_PENDING', throw
        # an exception if the crl_issuance_pending_accept config param
        # is not set
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_IN_STATE_CRL_ISSUANCE_PENDING';
    }
    if ($cert->{'STATUS'} eq 'REVOKED') {
        # certificate has been revoked already, throw an exception
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_IN_STATE_REVOKED';
    }
    elsif ($cert->{'STATUS'} eq 'HOLD' && $reason_code ne 'removeFromCRL') {
        # certificate is in state hold and reason code is not 'removeFromCRL'
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_ON_HOLD_AND_REASON_CODE_NOT_REMOVE_FROM_CRL';
    }
    elsif ($reason_code eq 'removeFromCRL' && $cert->{'STATUS'} ne 'HOLD') {
        # the other way round: reason is removeFromCRL but status is not
        # HOLD.
        condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_NOT_ON_HOLD_AND_REASON_CODE_REMOVE_FROM_CRL';
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::CertificateNotYetRevoked

=head1 SYNOPSIS

<action name="do_something">
  <condition name="certificate_not_yet_revoked"
             class="OpenXPKI::Server::Workflow::Condition::CertificateNotYetRevoked">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if the certificate from a CRR has not yet been
revoked. It furthermore throws an exception when the certificate
is in state 'HOLD' and the reason code is not 'removeFromCRL'.


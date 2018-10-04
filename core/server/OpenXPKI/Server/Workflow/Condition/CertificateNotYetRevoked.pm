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

sub evaluate {
    ##! 1: 'start'
    my ( $self, $workflow ) = @_;
    my $context     = $workflow->context();
    my $identifier  = $context->param('cert_identifier');
    my $reason_code = $context->param('reason_code');
    my $pki_realm   = CTX('session')->data->pki_realm;

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_IDENTIFIER_MISSING',
    ) unless $identifier;

    my $cert = CTX('dbi')->select_one(
        from => 'certificate',
        columns => [ 'status' ],
        where => {
            identifier => $identifier,
            pki_realm  => $pki_realm,
        }
    );

    CTX('log')->application()->debug("Cert status is ".$cert->{status});


    ##! 16: 'status: ' . $cert->{'STATUS'}

    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_IN_STATE_CRL_ISSUANCE_PENDING'
        if ('CRL_ISSUANCE_PENDING' eq $cert->{status});

    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_IN_STATE_REVOKED'
        if ('REVOKED' eq $cert->{status});

    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_ON_HOLD_AND_REASON_CODE_NOT_REMOVE_FROM_CRL'
        if ('HOLD' eq $cert->{status} and $reason_code ne 'removeFromCRL');

    condition_error 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_CERTIFICATE_NOT_YET_REVOKED_CERT_NOT_ON_HOLD_AND_REASON_CODE_REMOVE_FROM_CRL'
        if ($cert->{status} ne 'HOLD' and $reason_code eq 'removeFromCRL');

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


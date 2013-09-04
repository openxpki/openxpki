# OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest
# Written by Alexander Klink for the OpenXPKI project 2006
# Adopted for CRRs by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use DateTime;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi_backend');
    my $identifier = $context->param('cert_identifier');

    my $crr_serial = $dbi->get_new_serial(
        TABLE => 'CRR',
    );

    my $source_ref = $serializer->deserialize($context->param('sources'));
    if (! defined $source_ref) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CRR_PERSISTREQUEST_SOURCES_UNDEFINED',
        );
    }

    my $dt = DateTime->now();
    $dbi->insert(
            TABLE => 'CRR',
            HASH  => {
                'CRR_SERIAL'       => $crr_serial,
                'PKI_REALM'        => $pki_realm,
                'CREATOR'          => $context->param('creator'),
                'CREATOR_ROLE'     => $context->param('creator_role'),
                'IDENTIFIER'       => $context->param('cert_identifier'),
                'REASON_CODE'      => $context->param('reason_code'),
                'REVOCATION_TIME'  => $dt->epoch(),
                'INVALIDITY_TIME'  => $context->param('invalidity_time'),
                'COMMENT'          => $context->param('comment'),
                'HOLD_CODE'        => $context->param('hold_code'),
            },
    );
    $dbi->update(
        TABLE => 'CERTIFICATE',
        DATA  => {
            'STATUS' => 'CRL_ISSUANCE_PENDING',
        },
        WHERE => {
            'PKI_REALM'  => $pki_realm,
            'IDENTIFIER' => $identifier,
        },
    );
    $dbi->commit();
    $context->param('crr_serial' => $crr_serial);
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest

=head1 Description

persists the Certificate Revocation Request into the database, so that
it can then be used by the CRL issuance workflow.

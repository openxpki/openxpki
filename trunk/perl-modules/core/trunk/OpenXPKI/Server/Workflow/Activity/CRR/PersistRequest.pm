# OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest
# Written by Alexander Klink for the OpenXPKI project 2006
# Adopted for CRRs by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest';
use OpenXPKI::Serialization::Simple;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi_backend');
    my $crr_serial = $dbi->get_new_serial(
        TABLE => 'CRR',
    );

    my $source_ref = $serializer->deserialize($context->param('sources'));
    if (! defined $source_ref) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CRR_PERSISTREQUEST_SOURCES_UNDEFINED',
        );
    }

    my @list = (
                "creator", "creator_role",
                "cert_serial", "cert_identifier",
                "reason_name", "reason_subject", "reason_description",
                "compromise_time"
               );
    foreach my $field (@list)
    {
        my $source = $source_ref->{$field};
        if (! defined $source) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CSR_PERSISTREQUEST_SOURCE_UNDEFINED',
                params  => {"NAME" => $field, "VALUE" => $context->param($field)}
            );
        }

        ##! 64: 'source: ' . $source
        ##! 64: 'name:   ' . $field
        ##! 64: 'value:  ' . $$context->param($field)
        my $attrib_serial = $dbi->get_new_serial(
            TABLE => 'CRR_ATTRIBUTES',
        );
        $dbi->insert(
            TABLE => 'CRR_ATTRIBUTES',
            HASH  => {
                'ATTRIBUTE_SERIAL' => $attrib_serial,
                'PKI_REALM'        => $pki_realm,
                'CRR_SERIAL'       => $crr_serial,
                'ATTRIBUTE_KEY'    => $field,
                'ATTRIBUTE_VALUE'  => $context->param($field),
                'ATTRIBUTE_SOURCE' => $source,
            },
        );
    }
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

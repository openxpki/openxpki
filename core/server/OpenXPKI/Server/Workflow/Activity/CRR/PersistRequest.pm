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
    my $dbi        = CTX('dbi');
    my $identifier = $context->param('cert_identifier');

    my $source_ref = $serializer->deserialize($context->param('sources'));
    if (! defined $source_ref) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WF_ACTIVITY_CRR_PERSISTREQUEST_SOURCES_UNDEFINED',
        );
    }

    my $dt = DateTime->now();
    my $crr_serial = $dbi->next_id('crr');
    $dbi->insert(
        into => 'crr',
        values => {
            crr_key         => $crr_serial,
            pki_realm       => $pki_realm,
            creator         => $context->param('creator'),
            creator_role    => $context->param('creator_role'),
            identifier      => $context->param('cert_identifier'),
            reason_code     => $context->param('reason_code'),
            revocation_time => $dt->epoch(),
            invalidity_time => $context->param('invalidity_time'),
            crr_comment     => $context->param('comment'),
            hold_code       => $context->param('hold_code'),
        },
    );
    $dbi->update(
        table => 'certificate',
        set => {
            status => 'CRL_ISSUANCE_PENDING',
        },
        where => {
            pki_realm  => $pki_realm,
            identifier => $identifier,
        },
    );
    $context->param('crr_serial' => $crr_serial);

    CTX('log')->application()->debug("crr for $identifier persisted");

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest

=head1 Description

persists the Certificate Revocation Request into the database, so that
it can then be used by the CRL issuance workflow.

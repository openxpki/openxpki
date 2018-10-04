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

    my $cert = $dbi->select_one(
        from => 'certificate',
        columns => [ '*' ],
        where => {
            pki_realm  => $pki_realm,
            identifier => $identifier,
        },
    );

    if (!$cert) {
        OpenXPKI::Exception->throw(
            message => 'No such certificate in realm',
            params => {
                pki_realm  => $pki_realm,
                identifier => $identifier,
            }
        );
    }

    if ($cert->{status} ne 'ISSUED') {
        OpenXPKI::Exception->throw(
            message => 'Can not persist CRR, certificate is not in issued state',
            params => {
                identifier => $identifier,
                status => $cert->{status},
            }
        );
    }

    my $dt = DateTime->now();
    $dbi->update(
        table => 'certificate',
        set => {
            status => 'CRL_ISSUANCE_PENDING',
            reason_code     => $context->param('reason_code'),
            revocation_time => $dt->epoch(),
            invalidity_time => $context->param('invalidity_time') || undef,
            hold_instruction_code => $context->param('hold_code') || undef,
        },
        where => {
            pki_realm  => $pki_realm,
            identifier => $identifier,
        },
    );

    CTX('log')->application()->debug("revocation request for $identifier written to database");

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRR::PersistRequest

=head1 Description

persists the Certificate Revocation Request into the database, so that
it can then be used by the CRL issuance workflow.

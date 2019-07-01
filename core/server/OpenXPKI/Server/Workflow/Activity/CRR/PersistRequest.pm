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

    my $identifier = $self->param('cert_identifier') // $context->param('cert_identifier');

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

    my $reason_code = $context->param('reason_code') // $context->param('reason_code');
    my $invalidity_time = $self->param('invalidity_time') // $context->param('invalidity_time');
    my $hold_code = $self->param('hold_code') // $context->param('hold_code');

    my $dt = DateTime->now();
    $dbi->update(
        table => 'certificate',
        set => {
            status => 'CRL_ISSUANCE_PENDING',
            reason_code     => $reason_code || 'unspecified',
            revocation_time => $dt->epoch(),
            invalidity_time => $invalidity_time || undef,
            hold_instruction_code => $hold_code || undef,
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

=head2 Activity Parameters

By default, those values are read from the context items with the same name.
It a key with this name exists in the activity definition, it has precedence
over the context value. If a given key has an empty value, the context is
B<not> used as fallback.

=over

=item cert_identifier

=item reason_code

Must be one of the supported openssl reason codes, default is unspecified

=item invalidity_time

Epoch to be set as "key compromise time", the default backend uses this only
when reason_code is set to keyCompromise.

=item hold_code

Hold code for revocation reason "onHold" (not supported by the default backend).

=back

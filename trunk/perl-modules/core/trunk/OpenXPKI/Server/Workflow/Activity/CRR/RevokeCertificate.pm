# OpenXPKI::Server::Workflow::Activity::CRR::RevokeCertificate
# Written by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::CRR::RevokeCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CRR::RevokeCertificate';

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $dbi        = CTX('dbi_backend');

    $dbi->update(
        TABLE => 'CERTIFICATE',
        DATA  => {'STATUS' => 'CRL_ISSUANCE_PENDING'},
        WHERE => {
                  'PKI_REALM' => $pki_realm,
                  'ISSUER_IDENTIFIER' => $context->param('cert_issuer'),
                  'CERTIFICATE_SERIAL' => $context->param('cert_serial')
                 });
    $dbi->commit();
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRR::RevokeCertificate

=head1 Description

changes the status of the certificate in the database to a finally revoked
state.

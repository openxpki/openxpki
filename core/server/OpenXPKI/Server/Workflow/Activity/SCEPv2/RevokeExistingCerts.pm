# OpenXPKI::Server::Workflow::Activity::SCEPv2::RevokeExistingCerts
# Written by Alexander Klink for the OpenXPKI project 2006
# Adopted for CRRs by Michael Bell for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::RevokeExistingCerts;

=head1 NAME

OpenXPKI::Server::Workflow::Activity::SCEPv2::RevokeExisitngCerts;

=head1 DESCRIPTION

Fetch the list of active certs from the database and set the queue array I<tmp_queue>
and I<num_active_certs> in the the context. If no certs are found, the tmp_queue context
value is not set/purged from the context.

=cut

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use DateTime;

sub execute
{

    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context = $workflow->context();
    my $config = CTX('config');
    my $server = $context->param('server');

    my $csr_subject = $context->param('cert_subject');
    ##! 16: ' Revoking all active certs with subject ' . $csr_subject

    my $certs = CTX('api')->search_cert({
        VALID_AT => time(),
        STATUS => 'ISSUED',
        SUBJECT => $csr_subject
    });

    if (scalar(@{$certs})) {
        my $certs_to_revoke_wf = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
            {
            workflow    => $workflow,
            context_key => 'tmp_queue',
            } );

        foreach my $cert (@{$certs}) {
            ##! 32: 'Add cert to revoke ' . $cert->{IDENTIFIER}
           CTX('log')->application()->info("SCEP certificate added for automated revocation " . $cert->{IDENTIFIER});
            $certs_to_revoke_wf->push( $cert->{IDENTIFIER} );
        }
    } else {
        ##! 32: 'Unset queue - no certs to revoke'
        $context->param('tmp_queue' =>  );

        CTX('log')->application()->info("SCEP autorevoke - no active certs");

    }


    # reset the active cert counter
    $context->param('num_active_certs' => scalar(@{$certs}));

    return 1;
}

1;

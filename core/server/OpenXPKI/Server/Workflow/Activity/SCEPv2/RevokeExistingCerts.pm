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

    my $certs = CTX('api2')->search_cert(
        expires_after => time(),
        status => 'ISSUED',
        subject => $csr_subject,
        return_columns => 'identifier',
    );

    if (scalar(@{$certs})) {
        my $certs_to_revoke_wf = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
            {
            workflow    => $workflow,
            context_key => 'tmp_queue',
            } );

        foreach my $cert (@{$certs}) {
            ##! 32: 'Add cert to revoke ' . $cert->{identifier}
           CTX('log')->application()->info("SCEP certificate added for automated revocation " . $cert->{identifier});
            $certs_to_revoke_wf->push( $cert->{identifier} );
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

# OpenXPKI::Server::Workflow::Activity::CRR::MarkRevoked
# Written by Oliver Welter for the OpenXPKI project 2012 
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CRR::MarkRevoked;

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

    my $dbi        = CTX('dbi_backend');
    my $pki_realm = CTX('api')->get_pki_realm();     
    my $identifier = $context->param('cert_identifier');
 
   # TODO: Improve - load certificate, check status and fail on any error.
   # Status in db might already be revoked when using local issuance 
   # Fetch reason code from CRR db (onHold)
   
	# update certificate database:
    #my $status = 'REVOKED';
    #if ($reason_code eq 'certificateHold') {
    #        $status = 'HOLD';
    #}
   
   $dbi->update(
   		TABLE => 'CERTIFICATE',
        DATA  => {
            'STATUS' => 'REVOKED',
        },
        WHERE => {
        	'STATUS' => 'CRL_ISSUANCE_PENDING',
            'PKI_REALM'  => $pki_realm,
            'IDENTIFIER' => $identifier,
        },
    );
    $dbi->commit();    
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRR::MarkRevoked

=head1 Description

Mark the certificate as "revoked"
if reason_code is set to certificateHold, the certificate is put on status
HOLD, otherwise its set to REVOKED. 

=over

=item cert_identifier

=item reason_code

=back
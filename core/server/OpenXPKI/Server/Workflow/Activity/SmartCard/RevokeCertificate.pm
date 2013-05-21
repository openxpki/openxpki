# OpenXPKI::Server::Workflow::Activity::CertIssuance::PublishCertificate
# 
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::RevokeCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;


use Data::Dumper;

sub execute {
    my $self = shift;
    my $workflow = shift;
    my $context = $workflow->context();
        
    my $cert_identifier = $context->param('cert_identifier'); 
      
    # Create a new workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_REVOCATION_REQUEST',
        FILTER_PARAMS => 0,
        PARAMS        => { 
            cert_identifier => $cert_identifier,
            reason_code => 'superseded',
        	comment => '',
        	invalidity_time => time(),
	       flag_crr_auto_approval => 'yes',
        },
    });
        
    ##! 16: 'Revocation Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}

    CTX('log')->log(
    	MESSAGE => "Revocation workflow created for $cert_identifier, Wfl-Id ".$wf_info->{WORKFLOW}->{ID},
        PRIORITY => 'info',
        FACILITY => [ 'system' ],
	);    
    return 1;
    
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::RevokeCertificate;

=head1 Description

Trigger revocation of a certificate by starting an unwatched
workflow.

=head2 Context parameters

Expects the following context parameter:

=over 12

=item cert_identifier

=back

=head1 Functions

=head2 execute

Executes the action.

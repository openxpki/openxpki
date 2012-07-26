# OpenXPKI::Server::Workflow::Activity::CertIssuance::PublishCertificate
# 
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CertIssuance::PublishCertificate;

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

    my $workflow_type = $self->param('workflow_type');
    if (!$workflow_type) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_CERTISSUANCE_PUBLISH_CERTIFICATE_WORKFLOW_TYPE_NOT_GIVEN'
        );
    }
    
    my $cert_identifier = $context->param('cert_identifier');             
    my $cert_profile = $context->param('cert_profile');
    
    ##! 16: 'check if publishing is enabled for profile ' . $cert_profile     
     
    if (!CTX('config')->get("profile.$cert_profile.publish")) {
        ##! 32: 'Publishing not enabled for profile ' . $cert->{CSR.PROFILE}
        return 1;
    }
                
    # Create publishing workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => $workflow_type,
        FILTER_PARAMS => 0,
        PARAMS        => { 
            cert_identifier =>  $cert_identifier,
        },
    });
        
    ##! 16: 'Publishing Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}
        
    $context->param('workflow_publish_id', $wf_info->{WORKFLOW}->{ID} );
    
    return 1;
    
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Certificate::PublishCertificate

=head1 Description

Trigger publication to the configured backends by starting (unwatched)
workflows. The name of the workflow must be given in the activity definition.
The workflow is started only if I<publish: 1> is found in the profile definition.

The new workflow must accept the single parameter cert_identifier.

=head2 Activity parameters

=item workflow_type 

Name of the workflow that should be created

=head2 Context parameters

Expects the following context parameter:

=over 12

=item cert_identifier

=back

=head1 Functions

=head2 execute

Executes the action.

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
    
    
    # Copied legacy stuff - should probably be refactored  
    my $pki_realm = CTX('api')->get_pki_realm();
    my $cfg_id = $self->config_id();
    my $realm_config = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm};

    ##! 16: 'Check if LDAP is enabled'  
    if ($realm_config->{ldap_enable} ne 'yes') {
     ##! 16: 'LDAP not set - no publication'
     return 1;
    }
    
    my $cert_identifier = $context->param('cert_identifier'); 
    
    ##! 16: 'searching for certificate identifier ' . $cert_identifier
	my $cert = CTX('dbi_backend')->first(
	    TABLE   => 'CERTIFICATE',
	    COLUMNS => [
		  'DATA', 'ROLE'
	    ],
	    DYNAMIC => {
    		'IDENTIFIER' => $cert_identifier,
    		'STATUS'    => 'ISSUED',
    		'PKI_REALM' => $pki_realm,
	    },
	);

    ##! 32: 'certificate loaded: ' . Dumper( $cert ) 
    
    # Create a LDAP publishing workflow
    my $wf_info = CTX('api')->create_workflow_instance({
        WORKFLOW      => 'I18N_OPENXPKI_WF_TYPE_CERTIFICATE_LDAP_PUBLISHING',
        FILTER_PARAMS => 0,
        PARAMS        => { 
            certificate =>  $cert->{DATA},
            cert_role =>  $cert->{ROLE},
        },
    });
        
    ##! 16: 'LDAP Workflow created with id ' . $wf_info->{WORKFLOW}->{ID}
        
    $context->param('workflow_publish_ldap', $wf_info->{WORKFLOW}->{ID} );
    
    return 1;
    
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Certificate::PublishCertificate

=head1 Description

Trigger publication to the configured backends by starting (unwatched)
workflows. Uses the old LDAP publicaton mechanism at the moment.

=head2 Context parameters

Expects the following context parameter:

=over 12

=item cert_identifier

=back

=head1 Functions

=head2 execute

Executes the action.

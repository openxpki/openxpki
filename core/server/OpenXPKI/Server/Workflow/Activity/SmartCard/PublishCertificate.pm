# OpenXPKI::Server::Workflow::Activity::SmartCard::PublishCertificate
# Written by Martin Bartosch for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project

#FIXME - check if this can be merged with Tools::PublishCertificate
package OpenXPKI::Server::Workflow::Activity::SmartCard::PublishCertificate;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;




sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $pki_realm     = CTX('session')->get_pki_realm();        
    my $default_token = CTX('api')->get_default_token();
    my $config        = CTX('config');

    if (!$self->param('prefix')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISH_CERTIFICATE_NO_PREFIX'
        );
    }
     
    my $prefix = $self->param('prefix'); 

    if (!$self->param('publish_key')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISH_CERTIFICATE_NO_PUBLISH_KEY'
        );
     }

     my $publish_key =  $context->param( $self->param('publish_key') );
 
    ##! 16: 'Start publishing - load certificate for identifier ' . $context->param('cert_identifier')

    # Load and convert the certificate
    CTX('dbi_backend')->commit();
    my $hash = CTX('dbi_backend')->first (
        TABLE => 'CERTIFICATE',
        DYNAMIC => {
           IDENTIFIER => { VALUE => $context->param('cert_identifier') },
        },
    );
     
    if (!$hash || !$hash->{DATA}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATE_UNABLE_TO_LOAD_CERTIFICATE',
            params => { 'CERT_IDENTIFIER' => $context->param('cert_identifier') },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
        );
    }

    my $data = {};
    $data->{pem} = $hash->{DATA};
    $data->{subject} = $hash->{SUBJECT};
    
    # Convert to DER  
    
    $data->{der} = $default_token->command({
        COMMAND => 'convert_cert',
        DATA    => $data->{pem},
        OUT     => 'DER',
    }); 
    if (!defined $data->{der} || $data->{der} eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PUBLISHCERTIFICATES_COULD_NOT_CONVERT_CERT_TO_DER',
            log => {
	        logger => CTX('log'),
                priority => 'error',
                facility => 'system',
            },
        );
    }

    # Get the list of targets
    my @targets = $config->get_keys( "$prefix.targets" ); 
    
    # If the data point does not exist, we get a one item undef array
    return unless ($targets[0]);

    ##! 16: 'Publish targets at prefix '. $prefix .' -  ' . Dumper ( @targets )
    ##! 32: 'Data for publication '. Dumper ( $data )

    foreach my $target (@targets) {
       
        ##! 32: " $prefix.targets.$target.$publish_key " 
        my $res = $config->set( "$prefix.targets.$target.$publish_key" , $data );
        ##! 16 : 'Publish at target ' . $target . ' - Result: ' . $res
    }

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::PublishCertificates

=head1 Description

This class publishes a single certificate, identified by the context 
parameter. Publication is done using the connector using a list of
repositories. 

=head Configuration

Set the C<prefix> paramater to tell the activity where to find the connector
    <action name="scpers_publish_certificate"
       class="OpenXPKI::Server::Workflow::Activity::SmartCard::PublishSingleCertificate"
       prefix="smartcard.publishing"
       publish_key="userinfo_mail">
       <field name="cert_identifier" is_required="yes"/>
    </action>

Set up the connector using this syntax
       
    smartcard:
      publishing:
        targets:
          repo1@: connector:....
          repo2@: connector:....

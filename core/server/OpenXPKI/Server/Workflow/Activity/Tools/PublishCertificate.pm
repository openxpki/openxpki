# OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2009 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::DN;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;


sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $default_token = CTX('api')->get_default_token();   
    my $config        = CTX('config');

    if (!$self->param('prefix')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATE_NO_PREFIX'
        );
    }
     
    my $prefix = $self->param('prefix'); 

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
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATE_UNABLE_TO_LOAD_CERTIFICATE',
            params => { 'CERT_IDENTIFIER' => $context->param('cert_identifier') },
	    log => {
		logger => CTX('log'),
		priority => 'error',
		facility => 'system',
	    },
        );
    }

    # Get the list of targets
    my @targets = $config->get_keys( $prefix ); 
        
    CTX('log')->log(
        MESSAGE => 'Publication for ' . $hash->{SUBJECT} . ', prefix '.$prefix.', targets ' . join(",", @targets),    
        PRIORITY => 'debug',
        FACILITY => [ 'application' ],
    );  
    
    # If the data point does not exist, we get a one item undef array
    return unless ($targets[0]);

    ##! 16: 'Publish targets at prefix '. $prefix .' -  ' . Dumper ( @targets )

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
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CERTIFICATES_COULD_NOT_CONVERT_CERT_TO_DER',
            log => {
            logger => CTX('log'),
                priority => 'error',
                facility => 'system',
            },
        );
    }

    ##! 32: 'Data for publication '. Dumper ( $data )
  
    CTX('log')->log(
        MESSAGE => 'Start publication for ' .$data->{subject},    
        PRIORITY => 'info',
        FACILITY => [ 'application' ],
    );  
    
  
    # Strip the common name to be used as publishing key 
    my $dn_parser = OpenXPKI::DN->new( $data->{subject} );
     
    my %rdn_hash = $dn_parser->get_hashed_content();
     
    foreach my $target (@targets) {       
        ##! 32: " $prefix.$target . $rdn_hash{CN}[0] " 
        my $res = $config->set( [ $prefix, $target, $rdn_hash{CN}[0] ], $data );
        ##! 16 : 'Publish at target ' . $target . ' - Result: ' . $res
    }

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificates

=head1 Description

This class publishes a single certificate, identified by the context 
parameter. The data point you specify at prefix must contain a list
of connectors. Each connector is called with the value of the 
certificates common name as location. The data portion contains a hash ref
with the keys I<pem>, I<der> and I<subject> (full dn of the cert)

Publication is done using the connector using a list of
repositories. The com  

=head1 Configuration

Set the C<prefix> paramater to tell the activity where to find the connector
    <action name="publish_certificate"
       class="OpenXPKI::Server::Workflow::Activity::Tools::PublishCertificate"
       prefix="publishing.entity">
       <field name="cert_identifier" is_required="yes"/>
    </action>

Set up the connector using this syntax
           
  publishing:
    entity:
      repo1@: connector:....
      repo2@: connector:....

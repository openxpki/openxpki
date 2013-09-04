# OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL
# Written by Oliver Welter for the OpenXPKI project 2012
# Copyright (c) 2012 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL;

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
    my $config        = CTX('config');
    my $pki_realm = CTX('session')->get_pki_realm(); 

    if (!$self->param('prefix')) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_NO_PREFIX'
        );
    }
          
    my $default_token = CTX('api')->get_default_token();
    my $prefix = $self->param('prefix'); 
    my $ca_alias = $context->param('ca_alias');
    my $crl_serial = $context->param('crl_serial');
    
    if (!$ca_alias) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_NO_CA_ALIAS'
        );
    }
    if (!$crl_serial) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPI_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_NO_CRL_SERIAL'
        );
    }
        
    ##! 16: "Start publishing - CRL Serial $crl_serial , ca alias $ca_alias"           
    # Load the crl data     
    my $crl = CTX('dbi_backend')->first(
        TABLE   => 'CRL',
        KEY => $crl_serial
    );    
    
    if (!$crl || !$crl->{DATA}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_UNABLE_TO_LOAD_CRL',
            params => { 'CRL_SERIAL' => $context->param('crl_serial') },
            log => {
                logger => CTX('log'),
                priority => 'error',
                facility => 'system',
            });
    }
   
    # split of group and generation from alias
    $ca_alias =~ /^(.*)-(\d+)$/;
 
    my $data = {
        pem => $crl->{DATA},
        alias => $ca_alias,
        group => $1,
        generation => $2,
    };
    
    # Convert to DER
    $data->{der} = $default_token->command({
            COMMAND => 'convert_crl',
            DATA    => $crl->{DATA},
            OUT     => 'DER',
            });
            
    if (!defined $data->{der} || $data->{der} eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_PUBLISH_CRL_COULD_NOT_CONVERT_CRL_TO_DER',
            log => {
            logger => CTX('log'),
                priority => 'error',
                facility => 'system',
            },
        );
    }
    
    # Load issuer info    
    # FIXME - this might be improved using some caching
    my $certificate = CTX('api')->get_certificate_for_alias( { 'ALIAS' => $ca_alias });    
    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $certificate->{DATA},
        TOKEN => $default_token,
    );
        
    # Get Issuer Info from selected ca
    $data->{issuer} = $x509->{PARSED}->{BODY}->{SUBJECT_HASH};       
    $data->{subject} = $self->{PARSED}->{BODY}->{SUBJECT};
      
      
    # Get the list of targets
    my @targets = $config->get_keys( $prefix ); 
    
    # If the data point does not exist, we get a one item undef array
    return unless ($targets[0]);

    ##! 16: 'Publish targets at prefix '. $prefix .' -  ' . Dumper ( @targets )  
    
    # FIXME - Use exception handling to compensate failures
    ##! 32: 'Data for publication '. Dumper ( $data )      
    foreach my $target (@targets) {       
        ##! 32: " $prefix.$target . " . $data->{issuer}{CN}[0] 
        my $res = $config->set( [ "$prefix.$target.", $data->{issuer}{CN}[0] ], $data );
        ##! 16 : 'Publish at target ' . $target . ' - Result: ' . $res
        
        CTX('log')->log(
            MESSAGE => "CRL published at $prefix.$target with CN ".$data->{issuer}{CN}[0]." for CA $ca_alias in realm $pki_realm",
            PRIORITY => 'info',
            FACILITY => [ 'system' ],
        );        
    }

    # Set the publication date in the database
    my $dbi = CTX('dbi_backend');    
    $dbi->update(
        TABLE => 'CRL',
        DATA  => {
            'PUBLICATION_DATE' => DateTime->now()->epoch(),
        },
        WHERE => {
            'CRL_SERIAL' => $crl_serial,
        },
    );
    $dbi->commit();

    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::PublishCRLs

=head1 Description

This activity publishes a single crl. The context must hold the crl_serial 
and the ca_alias parameters. The data point you specify at prefix must contain
a list of connectors. Each connector is called with the CN of the issuing ca 
as location. The data portion contains a hash ref with the keys I<pem>, I<der>
and I<subject> (issuer subject) holding the appropriate strings and 
I<issuer> which is the issuer subject parsed into a hash as used in the 
template processing when issuing the certificates.  

=head1 Configuration

Set the C<prefix> paramater to tell the activity where to find the connector
    <action name="PUBLISH_CRL"
       class="OpenXPKI::Server::Workflow::Activity::Tools::PublishCRL"
       prefix="publishing.crl">
       <field name="crl_serial" is_required="yes"/>
       <field name="ca_alias" is_required="yes"/>
    </action>

Set up the connector using this syntax
           
  publishing:
    crl:
      repo1@: connector:....
      repo2@: connector:....
      
To publish the crl to your webserver, here is an example connector:

    cdp:
        class: Connector::Builtin::File::Path
        LOCATION: /var/www/myrealm/
        file: "[% ARGS %].crl"
        content: "[% pem %]"
      
The ARGS placeholder is replaced with the CN part of the issuing ca. So if you
name your ca generations as "ServerCA-1" and "ServerCA-2", you will end up
with two crls at "http://myhost/myrealm/ServerCA-1.crl" resp.
"http://myhost/myrealm/ServerCA-2.crl"      

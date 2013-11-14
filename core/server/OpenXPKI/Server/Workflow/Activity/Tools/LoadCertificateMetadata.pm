# OpenXPKI::Server::Workflow::Activity::Tools::LoadCertificateMetadata
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::LoadCertificateMetadata;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $params = $self->param();
    
    my $ser  = OpenXPKI::Serialization::Simple->new();
    
    my $cert_identifier = $context->param( 'cert_identifier' ); 

    if (! defined $cert_identifier) {
        OpenXPKI::Exception->throw(
            'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_LOADCERTIFICATEMETADATA_CERT_IDENTIFIER_NOT_DEFINED',
        );
    }
    
    ##! 16: 'cert_identifier ' . $cert_identifier
          
    my $cert_metadata = CTX('dbi_backend')->select(
        TABLE   => 'CERTIFICATE_ATTRIBUTES',
        DYNAMIC => {
            'IDENTIFIER' => { VALUE =>  $cert_identifier  },
            'ATTRIBUTE_KEY' => { OPERATOR => 'LIKE', VALUE => 'meta_%' },            
        },
    );
    
    my %arrays;
    ##! 16: ' Size of cert_metadata '. scalar( @{$cert_metadata} )
    foreach my $metadata (@{$cert_metadata}) {
        ##! 32: 'Examine Key ' . $metadata->{ATTRIBUTE_KEY}
        my $key = $metadata->{ATTRIBUTE_KEY};
        my $value = $metadata->{ATTRIBUTE_VALUE};
        if ($value =~ /^(ARRAY|HASH)/) {
            ##! 32: 'Deserialize '
            $value = $ser->deserialize( $value );
        }
        
        # represent a multivalued attribute, so use array
        if ($key =~ m{ \A (\w+)\[(\d+)] }xms) {
            ##! 32: 'add to array with key ' . $key            
            $arrays{$1.'[]'}->[$2] = $value;            
        } else {
            ##! 32: 'set context for ' . $key  
            $context->param( $key => $value );
        }
    }
    
    ##! 64: 'Non-scalar types ' . Dumper \%arrays 
    
    # write back the arrays
    foreach my $key (keys %arrays) {
        my $val = $ser->serialize( $arrays{$key} );
        ##! 64: 'Set key ' . $key . ' to ' . $val
        $context->param( $key => $ser->serialize( $arrays{$key} ) );
    }
    
    return 1;
    
}
    
1;

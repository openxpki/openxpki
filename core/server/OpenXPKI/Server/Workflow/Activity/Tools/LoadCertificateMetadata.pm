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
    
    my $context_data;
    ##! 16: ' Size of cert_metadata '. scalar( @{$cert_metadata} )
    foreach my $metadata (@{$cert_metadata}) {
        ##! 32: 'Examine Key ' . $metadata->{ATTRIBUTE_KEY}
        my $key = $metadata->{ATTRIBUTE_KEY};
        my $value = $metadata->{ATTRIBUTE_VALUE};
        if ($value =~ /^(ARRAY|HASH)/) {
            ##! 32: 'Deserialize '
            $value = $ser->deserialize( $value );
        }
       
        # find multivalues
        if ($context_data->{$key}) {
            ##! 32: 'set multivalue context for ' . $key            
            # on second element, create array with first one
            if (!ref $context_data->{$key}) {
                $context_data->{$key} = [ $context_data->{$key} ];
            }
            push @{$context_data->{$key}}, $value;                
        } else {
            ##! 32: 'set scalar context for ' . $key  
            $context_data->{$key} = $value;
        }        
    }
    
    # write to the context, serialize non-scalars and add []
    foreach my $key (keys %{$context_data}) {
        my $val = $context_data->{$key};
        if (ref $context_data->{$key}) {
            ##! 64: 'Set key ' . $key . ' to array ' . Dumper $val              
            $context->param( $key.'[]' => $ser->serialize( $val  ) );               
        } else {
            ##! 64: 'Set key ' . $key . ' to ' . $val            
            $context->param( $key => $val  );
        }        
    }
    
    return 1;
    
}
    
1;

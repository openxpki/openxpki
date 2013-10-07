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
    
    ##! 32: ' Size of cert_metadata '. scalar( @{$cert_metadata} )
    
    my $data = {};
    foreach my $metadata (@{$cert_metadata}) {
        ##! 51: 'Examine Key ' . $metadata->{ATTRIBUTE_KEY}
        my $key = $metadata->{ATTRIBUTE_KEY};
        $key =~ s{ \A meta_ }{}xms;
        
        my $value = $metadata->{ATTRIBUTE_VALUE};
        if ($value =~ /^(ARRAY|HASH)/) {
            ##! 32: 'Deserialize '
            $data->{$key} = $ser->deserialize( $value );
        } else {
            $data->{$key} = $value;
        }
    }
    
    ##! 32: 'Compiled meta data ' . Dumper $data
    $context->param('current_metadata' => $ser->serialize($data) );
    
    return 1;
    
}
    
1;
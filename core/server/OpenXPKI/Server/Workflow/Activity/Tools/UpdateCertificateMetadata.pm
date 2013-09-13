# OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::UpdateCertificateMetadata;

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

    my $cert_identifier = $context->param('cert_identifier');
     
    ##! 16: ' cert_identifier' . $cert_identifier   
    
  
    my $cert_metadata = CTX('dbi_backend')->select(
        TABLE   => 'CERTIFICATE_ATTRIBUTES',
        DYNAMIC => {
            'IDENTIFIER' => { VALUE =>  $cert_identifier  },
            'ATTRIBUTE_KEY' => { OPERATOR => 'LIKE', VALUE => 'meta_%' },            
        },
    );

    my $metadata_update = $context->param('metadata_update');
    
    if (!$metadata_update) {
         CTX('log')->log(
            MESSAGE => 'Nothing to update for cert_identifier ' . $cert_identifier,
            PRIORITY => 'info',
            FACILITY => 'audit',        
        );
    }
     
    my $new_data = $ser->deserialize( $metadata_update  ); 
    
    ##! 32: 'Update info ' . Dumper $new_data 
    
    ##! 32: ' Size of present metadata '. scalar( @{$cert_metadata} )
    
    my $dbi = CTX('dbi_backend');
    foreach my $metadata (@{$cert_metadata}) {
        ##! 51: 'Examine Key ' . $metadata->{ATTRIBUTE_KEY}
        my $key = $metadata->{ATTRIBUTE_KEY};
        $key =~ s{ \A meta_ }{}xms;
        
        if (not defined $new_data->{$key}) {
            ##! 32: 'No value for key in update - wont touch'
            next;
        }
        
        my $value = $new_data->{$key};
        $value = $ser->serialize( $value ) if (ref $value ne '');
        
        if ($value eq $metadata->{ATTRIBUTE_VALUE}) {
            ##! 32: 'Values are equal - no update'
            ##FIXME - there is chance that the serialization differes even if 
            # the value was not changed, so the update marker might be wrong 
            next;
        } else {
            
            ##! 32: sprintf 'change attr %s, old value %s, new value %s', $key, $metadata->{ATTRIBUTE_VALUE}, $value),
            CTX('log')->log(
                MESSAGE => sprintf ('cert metadata changed, cert %s, attr %s, new value %s',
                   $cert_identifier, $key, $value),
                PRIORITY => 'info',
                FACILITY => 'audit',        
            );
            $dbi->update(
                TABLE => 'CERTIFICATE_ATTRIBUTES', 
                DATA => {
                    ATTRIBUTE_VALUE => $value,
                },
                WHERE => {
                    ATTRIBUTE_SERIAL => $metadata->{ATTRIBUTE_SERIAL}
                }
            );
        }
        delete $new_data->{$key};
    }
    
    # Check if new items have been added
    foreach my $key (keys(%{$new_data})) {
        my $value = $new_data->{$key};
        next if ($value eq '');
        $value = $ser->serialize( $value ) if (ref $value ne '');
        CTX('log')->log(
            MESSAGE => sprintf ('cert metadata added, cert %s, attr %s, value %s',
               $cert_identifier, $key, $value),
            PRIORITY => 'info',
            FACILITY => 'audit',        
        );
                             
        ##! 32: 'Add new attribute ' . $key . ' value ' . $value
        my $serial = $dbi->get_new_serial(
            TABLE => 'CERTIFICATE_ATTRIBUTES',
        );
        $dbi->insert(
            TABLE => 'CERTIFICATE_ATTRIBUTES', 
            HASH => {
                ATTRIBUTE_SERIAL => $serial,
                IDENTIFIER => $cert_identifier,
                ATTRIBUTE_KEY => 'meta_'.$key,
                ATTRIBUTE_VALUE => $value,
            }
        );        
    }
    
    $dbi->commit();
    return 1;
    
}
    
1;
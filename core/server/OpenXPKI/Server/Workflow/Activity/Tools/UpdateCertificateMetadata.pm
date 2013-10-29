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
    
    # map database into kay/value hash
    my $current_meta = {};    
    foreach my $item (@{$cert_metadata}) {
       $current_meta->{$item->{ATTRIBUTE_KEY}} = $item; 
    }

    ##! 32: 'Current meta ' . Dumper $current_meta    

    my $param = $context->param();     
     
    ##! 32: 'Update info ' . Dumper $context
    
    my $dbi = CTX('dbi_backend');
    foreach my $key (keys %{$param}) {
        
        next if ($key !~ m{ \A meta_ }xms);
        
        # check if the key was registered before
        # todo - delete, non scalar items
        if ($current_meta->{$key}) {
            
            # key already present - do update
            
            # not changed - do nothing
            next if ($current_meta->{$key}->{ATTRIBUTE_VALUE} eq $param->{$key});
                       
            ##! 32: sprintf 'change attr %s, old value %s, new value %s', $key, $current_meta->{$key}->{ATTRIBUTE_VALUE}, $param->{$key}),
            CTX('log')->log(
                MESSAGE => sprintf ('cert metadata changed, cert %s, attr %s, new value %s',
                   $key, $current_meta->{$key}->{ATTRIBUTE_VALUE}, $param->{$key}),
                PRIORITY => 'info',
                FACILITY => 'audit',        
            );
            # delete if value is empty
            if ($param->{$key} eq '') {
                $dbi->delete(
                    TABLE => 'CERTIFICATE_ATTRIBUTES', 
                    DATA => {
                        ATTRIBUTE_SERIAL => $current_meta->{$key}->{ATTRIBUTE_SERIAL}
                    }
                );                 
            } else {
                $dbi->update(
                    TABLE => 'CERTIFICATE_ATTRIBUTES', 
                    DATA => {
                        ATTRIBUTE_VALUE => $param->{$key},
                    },
                    WHERE => {
                        ATTRIBUTE_SERIAL => $current_meta->{$key}->{ATTRIBUTE_SERIAL}
                    }
                );
            }
        } else {
            
            # insert new value
            CTX('log')->log(
                MESSAGE => sprintf ('cert metadata added, cert %s, attr %s, value %s',
                   $cert_identifier, $key, $param->{$key}),
                PRIORITY => 'info',
                FACILITY => 'audit',        
            );
                                 
            ##! 32: 'Add new attribute ' . $key . ' value ' . $param->{$key}
            my $serial = $dbi->get_new_serial(
                TABLE => 'CERTIFICATE_ATTRIBUTES',
            );
            $dbi->insert(
                TABLE => 'CERTIFICATE_ATTRIBUTES', 
                HASH => {
                    ATTRIBUTE_SERIAL => $serial,
                    IDENTIFIER => $cert_identifier,
                    ATTRIBUTE_KEY => $key,
                    ATTRIBUTE_VALUE => $param->{$key},
                }
            );        
            
        }
    }  
    $dbi->commit();
    return 1;
    
}
    
1;
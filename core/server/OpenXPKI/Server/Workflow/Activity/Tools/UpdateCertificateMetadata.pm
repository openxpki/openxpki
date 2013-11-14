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
                
    # map database into key/value hash
    my $current_meta = {};    
    foreach my $item (@{$cert_metadata}) {        
        # represent a multivalued attribute
        if ($item->{ATTRIBUTE_KEY} =~ m{ \A (\w+)\[(\d+)] }xms) {                         
            $current_meta->{$1.'[]'}->{$2} = $item;     
        } else {
            $current_meta->{$item->{ATTRIBUTE_KEY}} = $item;
        }         
    }

    ##! 32: 'Current meta ' . Dumper $current_meta    

    my $param = $context->param();     
     
    ##! 32: 'Update info ' . Dumper $context
    
    my $dbi = CTX('dbi_backend');
    foreach my $key (keys %{$param}) {
        
        next if ($key !~ m{ \A meta_ }xms);
        
        # non scalar items
        if ($key =~ m{ \A (\w+)\[\] }xms) {

            my $keybase = $1;
            my $curr = $current_meta->{$keybase.'[]'};
            my @values;
            
            # How this works:
            # The curr holds a hash with the key incl. the position
            # and the full dbi hash as value. To prevent key collisions
            # we need to run over the keys, set the values and save them
            # afterwards we delete anything that is left.
                        
            if (ref $param->{$key}) {
                @values = @{$param->{$key}}; 
            } else {
                @values = @{$ser->deserialize( $param->{$key} )};
            }
            
            my $pos = 0;
            foreach my $val (@values) {                
                            
                # check if there is a item at this postion
                if ($curr->{$pos}) {                                    
                    $dbi->update(
                        TABLE => 'CERTIFICATE_ATTRIBUTES', 
                        DATA => {                            
                            ATTRIBUTE_VALUE => $val,
                        },
                        WHERE => { ATTRIBUTE_SERIAL => $curr->{$pos}->{ATTRIBUTE_SERIAL} }
                    ) if ($val ne $curr->{$pos}->{ATTRIBUTE_VALUE});
                    delete $curr->{$pos};                    
                } else {                                 
                    ##! 32: 'Add new sub-attribute ' . $key . ' value ' . $param->{$key}
                    my $serial = $dbi->get_new_serial( TABLE => 'CERTIFICATE_ATTRIBUTES' );
                    $dbi->insert(
                        TABLE => 'CERTIFICATE_ATTRIBUTES', 
                        HASH => {
                            ATTRIBUTE_SERIAL => $serial,
                            IDENTIFIER => $cert_identifier,
                            ATTRIBUTE_KEY => $keybase.'['.$pos.']',
                            ATTRIBUTE_VALUE => $val
                        }
                    );      
                }
                $pos++;
            }
            
            # remove leftovers from the hash 
            foreach my $key (keys %{$curr}) {
                ##! 32: 'remove leftover sub-attribute at ' . $keybase.'['.$key.']' 
                $dbi->delete(
                    TABLE => 'CERTIFICATE_ATTRIBUTES', 
                    DATA => {                        
                        ATTRIBUTE_SERIAL => $curr->{$key}->{ATTRIBUTE_SERIAL}
                    }
                );
                delete $curr->{$key};
            }            
            
            # If we moved here from a scalar value, there might be one item left
            if ($current_meta->{$keybase}) {
                ##! 32: 'Delete scalar item at ' . $keybase
                $dbi->delete(
                    TABLE => 'CERTIFICATE_ATTRIBUTES', 
                    DATA => {                        
                        ATTRIBUTE_SERIAL => $current_meta->{$keybase}->{ATTRIBUTE_SERIAL}
                    }
                );
                delete $current_meta->{$keybase};
            }
        
        # check if the key was registered before
        } elsif ($current_meta->{$key}) {
            
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
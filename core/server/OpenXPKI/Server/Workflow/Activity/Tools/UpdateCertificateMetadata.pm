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

    # map current database info into 2-dim hash
    my $current_meta = {};    
    foreach my $item (@{$cert_metadata}) {            
        $current_meta->{$item->{ATTRIBUTE_KEY}}->{$item->{ATTRIBUTE_VALUE}} = $item;        
    }

    ##! 32: 'Current meta ' . Dumper $current_meta    

    my $param = $context->param();     
     
    ##! 32: 'Update info ' . Dumper $context
    
    my $dbi = CTX('dbi_backend');
    foreach my $key (keys %{$param}) {
        
        next if ($key !~ m{ \A meta_ }xms);
        
        my $curr; 
        # non scalar items - in context we have the square brackets!
        if ($key =~ m{ \A (\w+)\[\] }xms) {

            my $keybase = $1;
            ##! 32: 'non scalar key ' .$keybase            
            $curr = $current_meta->{$keybase};
            my @values;
            
            # the context might already be deserialized if we jump into a live workflow                        
            if (ref $param->{$key}) {
                @values = @{$param->{$key}}; 
            } else {
                @values = @{$ser->deserialize( $param->{$key} )};
            }
            
            # How this works:
            # The curr holds a hash with items values as key and the full dbi hash as value.
            # We run thru the context values and diff them against the curr hash
            # We remove items from curr if we want to keep them and delete anything left at the end
            foreach my $val (@values) {                                           
                # check if this value already exists
                if ($curr->{$val}) {
                    ##! 32: 'Value exists ' . $val
                    delete $curr->{$val};                
                } else {                                      
                    # does not exists, so create it                             
                    ##! 32: 'Add new sub-attribute ' . $key . ' value ' . $param->{$key}
                    my $serial = $dbi->get_new_serial( TABLE => 'CERTIFICATE_ATTRIBUTES' );
                    $dbi->insert(
                        TABLE => 'CERTIFICATE_ATTRIBUTES', 
                        HASH => {
                            ATTRIBUTE_SERIAL => $serial,
                            IDENTIFIER => $cert_identifier,
                            ATTRIBUTE_KEY => $keybase,
                            ATTRIBUTE_VALUE => $val
                        }
                    );      
                }
            }
            
        # scalar value - check if the key was registered before
        } elsif ($current_meta->{$key}) {
            
            $curr = $current_meta->{$key};
            
            ##! 16: 'existing scalar value at ' . $key
            
            # key already present - check the value
            # note - in case somebody wants to shift back from multivalue to scalar
            # there can be more than one key!
            my $val = $param->{$key};
            
            if (!defined $val) {
                ##! 32: 'undef - delete it'
                # noop - will get deleted by final loop            
            } elsif ($curr->{$val}) {
                # The value already exists, delete it from the hash to keep it
                ##! 32: 'unchanged'                                
                delete $curr->{$val};
            } else {
                ##! 32: 'updating'
                # take the first item from the hash and modify it
                keys %{$curr};
                my $oldval = shift; 
                my $serial = $curr->{$oldval}->{ATTRIBUTE_SERIAL};
                
                $dbi->update(
                    TABLE => 'CERTIFICATE_ATTRIBUTES', 
                    DATA => { ATTRIBUTE_VALUE => $val },
                    WHERE => { ATTRIBUTE_SERIAL => $serial }
                );
                                     
                ##! 32: sprintf 'change attr %s, old value %s, new value %s', $key, $current_meta->{$key}->{ATTRIBUTE_VALUE}, $param->{$key}),
                CTX('log')->log(
                    MESSAGE => sprintf ('cert metadata changed, cert %s, attr %s, new value %s',
                       $key, $oldval, $val),
                    PRIORITY => 'info',
                    FACILITY => 'audit',        
                );
            }           
        } elsif(defined $param->{$key}) {
            ##! 32: 'insert'
            # insert new value
            CTX('log')->log(
                MESSAGE => sprintf ('cert metadata added, cert %s, attr %s, value %s',
                   $cert_identifier, $key, $param->{$key}),
                PRIORITY => 'info',
                FACILITY => 'audit',        
            );
                                 
            ##! 32: 'Add new attribute ' . $key . ' value ' . $param->{$key}
            my $serial = $dbi->get_new_serial( TABLE => 'CERTIFICATE_ATTRIBUTES' );
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
        
        ##! 64: ' curr is ' . Dumper $curr
        
        # remove leftovers from the hash 
        foreach my $key (keys %{$curr}) {
            ##! 32: 'remove leftover attribute ' . $key 
            $dbi->delete(
                TABLE => 'CERTIFICATE_ATTRIBUTES', 
                DATA => {                        
                    ATTRIBUTE_SERIAL => $curr->{$key}->{ATTRIBUTE_SERIAL}
                }
            );
            delete $curr->{$key};
        }            
    
    }  
    $dbi->commit();
    return 1;
    
}
    
1;
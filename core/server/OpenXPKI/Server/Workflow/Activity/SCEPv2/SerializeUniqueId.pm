# OpenXPKI::Server::Workflow::Activity::SCEPv2::SerializeUniqueId
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::SerializeUniqueId;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use English;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Digest::SHA1 qw(sha1_hex);
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    
    my $context   = $workflow->context();
    
    my $token = CTX('api')->get_default_token();
    
    my $scep_tid = $context->param('scep_tid');
        
    my $csr_der = $token->command({
        COMMAND => 'convert_pkcs10',
        DATA    => $context->param('pkcs10'),
        OUT     => 'DER',
    });
    
    if (!$csr_der) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_WORKFLOW_SERVER_ACTIVITY_SCEP_SERIALIZEUNIQUEID_CONVERT_FAILED',
            params  => {
                'SCEP_TID' => $scep_tid,
            },
            log => {
                logger => CTX('log'),
                priority => 'error',
                facility => 'system',
            });
    }
    
    my $uniq_id = lc(sha1_hex($csr_der));           
    
    ##! 32: 'sha1 of csr : ' . $uniq_id           
    $context->param('scep_uniq_id' => $uniq_id);
    
    # We now try to set a datapool entry with the uniq_id used as key
    # This can fail if there is/was a second workflow for this transaction
    # We MUST do a db commit here to ensure the value is really uniq!
    
    eval {
        CTX('dbi_backend')->commit();    
        CTX('api')->set_data_pool_entry({       
            NAMESPACE => 'scep.uniq_id',
            KEY => $uniq_id,
            VALUE => $workflow->id,        
            EXPIRATION_DATE => 0,
         });
        CTX('dbi_backend')->commit();
    };
    # Most likely we failed as the key is alredy present in the datastore
    my $ee = $EVAL_ERROR;
    if ($ee) {
        ##! 16: 'Failed to write datapool - eval: ' . $ee
        $context->param('scep_uniq_id_ok' => 0); 
        CTX('log')->log(
            MESSAGE  => sprintf ("SCEP UniqId collision - SCEP Id: %s, UniqId: %s, CSR Subject: %s ", $scep_tid, $uniq_id, $context->param('cert_subject')),
            PRIORITY => 'error',
            FACILITY => ['system','audit']
        );    
    } else {
        ##! 32: 'datapool written'
        $context->param('scep_uniq_id_ok' => 1);               
        CTX('log')->log(
            MESSAGE  => sprintf ("SCEP UniqId validated - SCEP Id: %s, UniqId: %s, CSR Subject: %s ", $scep_tid, $uniq_id, $context->param('cert_subject')),
            PRIORITY => 'info',
            FACILITY => 'system'
        );          
    }    
        
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEPv2::SerializeUniqueId

=head1 Description

This activity calculates the requests unique id and writes it at scep_uniq_id
into the context. The id is created from the hex representation of the sha1 
hash of the CSR and the first 32 chars of the transaction id (all lowercased).

It also tries to write the uniqid to the datapool which can fail if the request
is a duplicate in the system. The uniq id is used as key, the workflow id as the
value. The context value scep_uniq_id_ok is 1 if writing the datapool was 
successful.


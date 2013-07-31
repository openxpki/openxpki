## OpenXPKI::Service::SCEPv2::Command::PKIOperation
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## Rewrite 2013 by Oliver Welter
## (C) Copyright 2006-2013 by The OpenXPKI Project
##
package OpenXPKI::Service::SCEPv2::Command::PKIOperation;
use base qw( OpenXPKI::Service::SCEPv2::Command );

use strict;

use English;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;
use Data::Dumper;
use MIME::Base64;
use Math::BigInt;
use DateTime::Format::DateParse;

=head1 Name

OpenXPKI::Service::SCEPv2::Command::PKIOperation

=head1 Description

Implements the functionality required to answer SCEP PKIOperation messages.

=head1 Functions

=head2 execute

Parses the PKCS#7 container for the message type, calls a function
depending on that type and returns the result, including the HTTP
header needed for the scep CGI script.

=cut

sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;
    my $result;

    my $params = $self->get_PARAMS();
    
    my $url_params = $params->{URLPARAMS} || {}; 
    
    my $pkcs7_base64 = $params->{MESSAGE};    
    ##! 64: 'pkcs7_base64: ' . $pkcs7_base64
    my $pkcs7_decoded = decode_base64($pkcs7_base64);

    my $api       = CTX('api');
    my $pki_realm = CTX('session')->get_pki_realm();
    my $server    = CTX('session')->get_server();

    my $token = $self->__get_token();    

    my $message_type_ref = $token->command(
        {   COMMAND => 'get_message_type',
            PKCS7   => $pkcs7_decoded,
        }
    );

    ##! 32: 'PKI msg ' . Dumper $message_type_ref

    if ( $message_type_ref->{MESSAGE_TYPE_NAME} eq 'PKCSReq' ) {
        $result = $self->__pkcs_req(
            {   TOKEN => $token,
                PKCS7 => $pkcs7_base64,
                PARAMS => $url_params, 
            }
        );
    }
    elsif ( $message_type_ref->{MESSAGE_TYPE_NAME} eq 'GetCertInitial' ) {

        # used by sscep after sending first request for polling
        $result = $self->__pkcs_req(
            {   TOKEN => $token,
                PKCS7 => $pkcs7_base64,
                PARAMS => $url_params,                
            }
        );
    }
    elsif ( $message_type_ref->{MESSAGE_TYPE_NAME} eq 'GetCert' ) {

        ##! 32: 'PKCS7 GetCert ' . $pkcs7_base64
        $result = $self->__send_cert(
            {   TOKEN => $token,
                PKCS7 => $pkcs7_decoded,
                PARAMS => $url_params,                
            }
        );

    }    
    else {
        $result = $token->command(
            {   COMMAND      => 'create_error_reply',
                PKCS7        => $pkcs7_decoded,
                'ERROR_CODE' => 'badRequest',
            }
        );
    }

    $result = "Content-Type: application/x-pki-message\n\n" . $result;
    return $self->command_response($result);
}


=head2 __get_workflow_type

Read the workflow type that this server is configured for from the connector.
 
=cut 
sub __get_workflow_type : PRIVATE {
    
    my $self      = shift;
    my $server    = CTX('session')->get_server();
    
    my $workflow_type = CTX('config')->get("scep.$server.workflow_type");
    
    OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_NO_WORKFLOW_TYPE_DEFINED",
        params => {
            SERVER => $server,
            REALM =>  CTX('session')->get_pki_realm()
        }
    ) unless($workflow_type);
    
    return $workflow_type;
}

=head2 __send_cert

Create the response for the GetCert request by extracting the serial number 
from the request, find the certificate and return it.

=cut

sub __send_cert : PRIVATE {
    my $self      = shift;
    my $arg_ref   = shift;
    
    my $token = $arg_ref->{TOKEN};
    my $pkcs7_decoded = $arg_ref->{PKCS7};
    
    my $requested_serial_hex = $token->command({   
        COMMAND => 'get_getcert_serial',
        PKCS7   => $pkcs7_decoded,
    });

    # Serial is in Hex Format - we need decimal!
    my $mbi = Math::BigInt->from_hex( "0x$requested_serial_hex" );       
    my $requested_serial_dec = scalar $mbi->bstr();
    
    ##! 16: 'Found serial - hex: ' . $requested_serial_hex . ' - dec: ' . $requested_serial_dec
                    
    my $cert_result = CTX('api')->search_cert({ 'CERT_SERIAL' => $requested_serial_dec });
    
    ##! 32: 'Search result ' . Dumper $cert_result 
    my $cert_count = scalar @{$cert_result};
    
    # more than one - no usable result
    if ($cert_count > 1) {
        OpenXPKI::Exception->throw(
            message =>
                "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_GETCERT_MORE_THAN_ONE_CERTIFICATE_FOUND",
            params => {
                COUNT => $cert_count,
                SERIAL_HEX => $requested_serial_hex,
                SERIAL_DEC => $requested_serial_dec,
            },
            log => {
                logger => CTX('log'),
                priority => 'error',
                facility => 'system',
            },
        );          
    }
    
    if ($cert_count == 0) {
         CTX('log')->log(
            MESSAGE => "SCEP getcert - no certificate found for serial $requested_serial_hex",
            PRIORITY => 'info',
            FACILITY => 'system',
        );             
        
        return $token->command(
            {   COMMAND      => 'create_error_reply',
                PKCS7        => $pkcs7_decoded,
                'ERROR_CODE' => 'badCertId',
            }
        );  
    }
    
    my $cert_identifier  = $cert_result->[0]->{'IDENTIFIER'};
    ##! 16: 'Load Cert Identifier ' . $cert_identifier 
    my $cert_pem = CTX('api')->get_cert({ 'IDENTIFIER' => $cert_identifier, 'FORMAT' => 'PEM' });

    ##! 16: 'cert data ' . Dumper $cert_pem
    my $result = $token->command(
        {   COMMAND        => 'create_certificate_reply',
            PKCS7          => $pkcs7_decoded,
            CERTIFICATE    => $cert_pem,
            ENCRYPTION_ALG => CTX('session')->get_enc_alg(),
        }
    );
    return $result;
}

=head2 __pkcs_req

Called by execute if the message type is 'PKCSReq' (19). This is the
message type that is used when an SCEP client asks for a certificate.
Named parameters are TOKEN and PKCS7, where token is a token from the
OpenXPKI::Crypto::TokenManager of type 'SCEP'. PKCS7 is the PKCS#7 data
received from the client. Using the crypto token, the transaction ID of
the request is acquired. Using this transaction ID, a database lookup is done
(using the server API search_workflow_instances function) to see whether
there is already an existing workflow corresponding to the transaction ID.

If there is no workflow, a new one of type I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST
is created and the (base64-encoded) PKCS#7 request as well as the transaction
ID is saved in the workflow context. From there on, the work takes place in
the workflow.

If there is a workflow, the status of this workflow is looked up and the response
depends on the status:
  - if the status is not 'SUCCESS' or 'FAILURE', the request is still
    pending, and a corresponding message is returned to the SCEP client.
  - if the status is 'SUCESS', the certificate is extracted from the
    workflow and returned to the SCEP client.
  - if the status is 'FAILURE', the failure code is extracted from the
    workflow and returned to the client

=cut 

sub __pkcs_req : PRIVATE {
    my $self      = shift;
    my $arg_ref   = shift;
    my $api       = CTX('api');
    my $pki_realm = CTX('session')->get_pki_realm();
    my $profile   = CTX('session')->get_profile();
    my $server    = CTX('session')->get_server();

    my $workflow_type = $self->__get_workflow_type();

    my $url_params =  $arg_ref->{PARAMS};

    my $pkcs7_base64 = $arg_ref->{PKCS7};
    ##! 64: 'pkcs7_base64: ' . $pkcs7_base64
    my $pkcs7_decoded = decode_base64($pkcs7_base64);
    my $token         = $arg_ref->{TOKEN};

    my $transaction_id = $token->command(
        {   COMMAND => 'get_transaction_id',
            PKCS7   => $pkcs7_decoded,
        }
    );

    ##! 16: "transaction ID: $transaction_id"
    # get workflow instance IDs corresponding to transaction ID
    # TODO: This search should be limited to SCEP workflow types!!!
    my $workflows = $api->search_workflow_instances(
        {   CONTEXT => [
                {   KEY   => 'scep_tid',
                    VALUE => $transaction_id,
                },
            ],
            TYPE => $self->__get_workflow_type(),
        }
    );
    ##! 16: 'workflows: ' . Dumper $workflows

    my $failure_retry;
    if ( scalar @{$workflows} > 0 ) {
 
        if ( $workflows->[0]->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE' ) {

            # the last workflow is in FAILURE, check the last update
            # date to see if user is already allowed to retry
            my $last_update
                = $workflows->[0]->{'WORKFLOW.WORKFLOW_LAST_UPDATE'};
            ##! 16: 'FAILURE workflow found, last update: ' . $last_update
            my $last_update_dt
                = DateTime::Format::DateParse->parse_datetime( $last_update,
                'UTC' );
            ##! 32: 'last update dt: ' . Dumper $last_update_dt

            # determine retry time from config
            my $retry_time = CTX('config')->get("scep.$server.retry_time");
            
            if ( !defined $retry_time ) {
                $retry_time = '000001';    # default is one day
            }
            ##! 16: 'retry time: ' . $retry_time

            my $retry_date = OpenXPKI::DateTime::get_validity(
                {   REFERENCEDATE  => DateTime->now(),
                    VALIDITY       => '-' . $retry_time,
                    VALIDITYFORMAT => 'relativedate',
                }
            );
            ##! 32: 'retry_date: ' . Dumper $retry_date
            if ( DateTime->compare( $last_update_dt, $retry_date ) == -1 ) {
                ##! 64: 'last update is earlier than retry date, allow creation of new WF'
                # set DB result to empty, so that it looks like no wf is present
                $workflows = [];
            }
            else {
                ##! 64: 'last update is later than retry date, do not allow creation of new WF'
                # only include the first FAILURE wf in the result -> SCEP failure response
                $workflows = [ $workflows->[0] ];
            }
        }
    }
    if ( scalar @{$workflows} > 1 ) {

        # if more than one workflow is present, we delete the FAILURE ones
        # from it
        my @no_fail_workflows
            = grep { $_->{'WORKFLOW.WORKFLOW_STATE'} ne 'FAILURE' }
            @{$workflows};
        $workflows = \@no_fail_workflows;
        
    }
    ##! 16: 'workflows after retry checking: ' . Dumper $workflows

    my @workflow_ids = map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @{$workflows};

    my $num_of_workflows = scalar @workflow_ids;
    ##! 16: " $num_of_workflows workflows found"    
    if ( $num_of_workflows > 1 ) {    # this should _never_ happen ...
        OpenXPKI::Exception->throw(
            message =>
                "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_MORE_THAN_ONE_WORKFLOW_FOUND",
            params => {
                WORKFLOWS      => $num_of_workflows,
                TRANSACTION_ID => $transaction_id,
            }
        );
    }

    my $wf_info; # filled in either one of the branches 
    
    if ( scalar @workflow_ids == 0 ) {
        ##! 16: "no workflow was found, creating a new one"
 
        # inject newlines if not already present
        # this is necessary for openssl / openca-scep to parse
        # the data correctly
        ##! 64: 'pkcs7_base64 before sanitizing: __START__' . $pkcs7_base64 . '__END__'
        $pkcs7_base64 =~ s{ \n }{}xmsg;
        my $divides64;
        ##! 64: 'length: ' . length($pkcs7_base64)
        if ( length($pkcs7_base64) % 64 == 0 ) {
            $divides64 = 1;
        }
        $pkcs7_base64 =~ s{ (.{64}) }{$1\n}xmsg;
        
        if ( !$divides64 ) {
            ##! 64: 'pkcs7 length does not divide 64, add an additional newline'
            $pkcs7_base64 .= "\n";
        }
        ##! 64: 'pkcs7_base64 before create_wf_instance: ' . $pkcs7_base64

        #### Extract CSR from pkcs7
        my $pkcs7 = "-----BEGIN PKCS7-----\n" . $pkcs7_base64 . "-----END PKCS7-----\n";

        # get a crypto token of type 'SCEP'
        my $token = $self->__get_token();
           
        my $pkcs10 = $token->command(
            {   COMMAND => 'get_pkcs10',
                PKCS7   => $pkcs7,
            }
        );
        
        ##! 64: "pkcs10 is " . $pkcs10;
        if ( not defined $pkcs10 || $pkcs10 eq '' ) {
            OpenXPKI::Exception->throw( message =>
                    "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_PKCS10_UNDEFINED",
            );
        }

        my $signer_cert = $token->command(
            {   COMMAND => 'get_signer_cert',
                PKCS7   => $pkcs7,
            }
        );
    
        ##! 64: "signer_cert: " . $signer_cert        
        
        # The maximum age until the workflow is considered outdated 
        #my $expiry = CTX('config')->get("scep.$server.workflow_expiry");
        
        #my $expirydate = OpenXPKI::DateTime::get_validity({            
        #    VALIDITY => '+'.$expiry,
        #    VALIDITYFORMAT => 'relativedate',
        #});
        
        $wf_info = $api->create_workflow_instance(
            {   WORKFLOW => $self->__get_workflow_type(),
                PARAMS   => {
                    'scep_tid'    => $transaction_id,
                    'signer_cert' => $signer_cert,
                    'pkcs10'         => $pkcs10,

                    #'expires' => $expirydate->epoch(),

                    # not sure if these need to be passed here
                    'cert_profile' => $profile,
                    'server'       => $server,

                    # necessary to check the signature - volatile only 
                    '_pkcs7' => $pkcs7, # contains scep_tid, signer_cert, csr
                    
                    # Extra url params - as we never write them to the backend,
                    # we can pass the plain hash here (no serialization)
                    '_url_params' => $url_params,
                }
            }
        );       

        ##! 16: 'wf_info: ' . Dumper $wf_info
        $workflow_ids[0] = $wf_info->{WORKFLOW}->{ID};
        ##! 16: '@workflow_ids: ' . Dumper \@workflow_ids
    } 
    else {    # everything is fine, we have only one matching workflow
        my $wf_id   = $workflow_ids[0];
        $wf_info = $api->get_workflow_info(
            {   WORKFLOW => $self->__get_workflow_type(),
                ID       => $wf_id,
            }
        );
             
        # TODO - Branch can be substituted with Watchdog        
        if ( $wf_info->{WORKFLOW}->{STATE} eq 'CA_KEY_NOT_USABLE' ) {
 
            my $activities = $api->get_workflow_activities(
                {   WORKFLOW => $self->__get_workflow_type(),
                    ID       => $wf_id,
                }
            );
            ##! 32: 'activities: ' . Dumper $activities
            if ( defined $activities && scalar @{$activities} > 1 ) {

                # this should _never_ happen
                OpenXPKI::Exception->throw( message =>
                        'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_MORE_THAN_ONE_ACTIVITY_FOUND',
                );
            }
            elsif ( defined $activities && scalar @{$activities} == 1 ) {

                # execute possible activity
                $api->execute_workflow_activity(
                    {   WORKFLOW => $self->__get_workflow_type(),
                        ID       => $wf_id,
                        ACTIVITY => $activities->[0],
                    }
                );

                # get new info and state
                $wf_info = $api->get_workflow_info(
                    {   WORKFLOW => $self->__get_workflow_type(),
                        ID       => $wf_id,
                    }
                );
       
                ##! 16: 'new state after triggering activity: ' . $wf_info->{WORKFLOW}->{STATE}
            }
        }
    } # End refetched workflow
        
       
    # wf_info is either from create or from fetch!
    my $wf_state = $wf_info->{WORKFLOW}->{STATE};
    
    if ( $wf_state ne 'SUCCESS' && $wf_state ne 'FAILURE' ) {        
        # we are still pending
        my $pending_msg = $token->command(
            {   COMMAND => 'create_pending_reply',
                PKCS7   => $pkcs7_decoded,
            }
        );
        return $pending_msg;
    }
        
    if ( $wf_state eq 'SUCCESS' ) {  
        # the workflow is finished,
        # get the CSR serial from the workflow
        
        my $cert_identifier = $wf_info->{WORKFLOW}->{CONTEXT}->{'cert_identifier'};
        ##! 32: 'cert_identifier: ' . $cert_identifier
 
        my $certificate = $api->get_cert(
            {   IDENTIFIER => $cert_identifier,
                FORMAT     => 'PEM',
            }
        );
        ##! 16: 'certificate: ' . $certificate

        if ( !defined $certificate ) {
            OpenXPKI::Exception->throw(
                message =>
                    'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_GET_CERT_FAILED',
                params => { IDENTIFIER => $cert_identifier, }
            );
        }

        my $certificate_msg = $token->command(
            {   COMMAND        => 'create_certificate_reply',
                PKCS7          => $pkcs7_decoded,
                CERTIFICATE    => $certificate,
                ENCRYPTION_ALG => CTX('session')->get_enc_alg(),
            }
        );

        CTX('log')->log(
            MESSAGE => "Delivered certificate via SCEP ($cert_identifier)",
            PRIORITY => 'info',
            FACILITY => 'system',
        );

        return $certificate_msg;
    }
        
    ##! 32: 'FAILURE'
    my $error_code = $wf_info->{WORKFLOW}->{CONTEXT}->{'error_code'};
    if ( !defined $error_code ) {
        #OpenXPKI::Exception->throw( message =>
        #        'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_FAILURE_BUT_NO_ERROR_CODE',
        #);
        CTX('log')->log(
            MESSAGE => "SCEP Request failed without error code set - default to badRequest",
            PRIORITY => 'info',
            FACILITY => 'system',
        );
        $error_code = 'badRequest';
    }
    my $error_msg = $token->command(
        {   COMMAND      => 'create_error_reply',
            PKCS7        => $pkcs7_decoded,
            'ERROR_CODE' => $error_code,
        }
    );
    return $error_msg;
}

=head2 __get_token 

Get the scep token from the crypto layer

=cut
sub __get_token {
           
    # TODO-SCEPv2 - swap active version
         
    # HEAD Version
    my $scep_token_alias = CTX('api')->get_token_alias_by_type( { TYPE => 'scep' } );
    my $token = CTX('crypto_layer')->get_token( { TYPE => 'scep', NAME => $scep_token_alias } );

    if ( !defined $token ) {
        ##! 16: "No token found for alias $scep_token_alias"
        OpenXPKI::Exception->throw( 
            message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_SCEP_TOKEN_MISSING',
            params => { ALIAS => $scep_token_alias }
        );
    }
    
    return $token;
    
}


1;    # magic one at the end of module
__END__
 
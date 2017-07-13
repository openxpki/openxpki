## OpenXPKI::Service::SCEP::Command::PKIOperation
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## Rewrite 2013 by Oliver Welter
## (C) Copyright 2006-2013 by The OpenXPKI Project
##
package OpenXPKI::Service::SCEP::Command::PKIOperation;
use base qw( OpenXPKI::Service::SCEP::Command );

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

OpenXPKI::Service::SCEP::Command::PKIOperation

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
    my @extra_header;

    my $params = $self->get_PARAMS();

    my $url_params = $params->{URLPARAMS} || {};

    my $pkcs7_base64 = $params->{MESSAGE};
    ##! 64: 'pkcs7_base64: ' . $pkcs7_base64
    my $pkcs7_decoded = decode_base64($pkcs7_base64);

    my $api       = CTX('api');
    my $pki_realm = CTX('session')->data->pki_realm;
    my $server    = CTX('session')->data->server;

    my $token = $self->__get_token();

    my $message_type_ref = $token->command(
        {   COMMAND => 'get_message_type',
            PKCS7   => $pkcs7_decoded,
        }
    );

    ##! 32: 'PKI msg ' . Dumper $message_type_ref

    if ( $message_type_ref->{MESSAGE_TYPE_NAME} eq 'PKCSReq' ) {
        my $resp = $self->__pkcs_req(
            {   TOKEN => $token,
                PKCS7 => $pkcs7_base64,
                PARAMS => $url_params,
            }
        );
        $result = $resp->[1];
        if ($resp->[0] && (ref $resp->[0] eq 'ARRAY')) {
            @extra_header = @{$resp->[0]};
        }
    }
    elsif ( $message_type_ref->{MESSAGE_TYPE_NAME} eq 'GetCertInitial' ) {

        # used by sscep after sending first request for polling
        my $resp = $self->__pkcs_req(
            {   TOKEN => $token,
                PKCS7 => $pkcs7_base64,
                PARAMS => $url_params,
            }
        );
        $result = $resp->[1];
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
    elsif ( $message_type_ref->{MESSAGE_TYPE_NAME} eq 'GetCRL' ) {

        ##! 32: 'PKCS7 GetCRL ' . $pkcs7_base64
        $result = $self->__send_crl(
            {   TOKEN => $token,
                PKCS7 => $pkcs7_base64,
                PARAMS => $url_params,
            }
        );

    }
    else {
        $result = $token->command(
            {   COMMAND      => 'create_error_reply',
                PKCS7        => $pkcs7_decoded,
                HASH_ALG     => CTX('session')->data->hash_alg,
                'ERROR_CODE' => 'badRequest',
            }
        );
    }

    push @extra_header, "Content-Type: application/x-pki-message";
    my $header = join("\n", @extra_header );
    return $self->command_response( $header . "\n\n" . $result);
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
                priority => 'error',
                facility => 'application',
            },
        );
    }

    if ($cert_count == 0) {
         CTX('log')->application()->info("SCEP getcert - no certificate found for serial $requested_serial_hex");


        return $token->command(
            {   COMMAND      => 'create_error_reply',
                PKCS7        => $pkcs7_decoded,
                HASH_ALG     => CTX('session')->data->hash_alg,
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
            HASH_ALG       => CTX('session')->data->hash_alg,
            ENCRYPTION_ALG => CTX('session')->data->enc_alg,
        }
    );
    return $result;
}


=head2 __send_crl

Create the response for the GetCRL request by extracting the used CA certificate
from the request and returning its crl.

=cut

sub __send_crl : PRIVATE {
    my $self      = shift;
    my $arg_ref   = shift;

    my $token = $arg_ref->{TOKEN};
    my $pkcs7_base64 = $arg_ref->{PKCS7};
    my $pkcs7_decoded = decode_base64($pkcs7_base64);

    my $requested_issuer_serial = $token->command({
        COMMAND => 'get_getcrl_issuer_serial',
        PKCS7   => $pkcs7_decoded
    });

    ##! 16: 'Issuer Serial ' . Dumper $requested_issuer_serial

    # convert serial to decimal
    my $mbi = Math::BigInt->from_hex( $requested_issuer_serial->{SERIAL} );
    my $issuer_serial = scalar $mbi->bstr();

    # from scep draft (as of March 2015)
    # ..containing the issuer name and serial number of
    # the certificate whose revocation status is being checked.
    # -> we search for this entity certificate and grab the issuer from the
    # certificate table, this will also catch situations where the Issuer DN
    # is reused over generations as the serial inside OXI is unique

    my $res = CTX('api')->search_cert({
        PKI_REALM => '_ANY',
        ISSUER_DN => $requested_issuer_serial->{ISSUER},
        CERT_SERIAL => $issuer_serial,
    });

    if (!$res || scalar @{$res} != 1) {
          CTX('log')->application()->error("SCEP getcrl - no issuer found for serial $issuer_serial and issuer " . $requested_issuer_serial->{ISSUER});


        return $token->command(
            {   COMMAND      => 'create_error_reply',
                PKCS7        => $pkcs7_decoded,
                HASH_ALG     => CTX('session')->data->hash_alg,
                'ERROR_CODE' => 'badCertId',
            }
        );
    }

    ##! 32: 'Issuer Info ' . Dumper $res

    my $crl_res = CTX('api')->get_crl_list({
        ISSUER => $res->[0]->{ISSUER_IDENTIFIER},
        FORMAT => 'PEM',
        LIMIT => 1
    });

    if (!scalar $crl_res) {
        return $token->command(
            {   COMMAND      => 'create_error_reply',
                PKCS7        => $pkcs7_decoded,
                HASH_ALG     => CTX('session')->data->hash_alg,
                'ERROR_CODE' => 'badCertId',
            }
        );
    }

    ##! 32: 'CRL Result ' . Dumper $crl_res
    my $crl_pem = $crl_res->[0];

    my $result = $token->command(
        {   COMMAND        => 'create_crl_reply',
            PKCS7          => $pkcs7_decoded,
            CRL            => $crl_pem,
            HASH_ALG       => CTX('session')->data->hash_alg,
            ENCRYPTION_ALG => CTX('session')->data->enc_alg,
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
(using the datapool) to see whether
there is already an existing workflow corresponding to the transaction ID.

If there is no workflow, a new one of the type defined in the server configuration
is created and the (base64-encoded) PKCS#7 request as well as the transaction
ID is saved in the workflow context. From there on, the work takes place in
the workflow.

If there is a workflow, the status of this workflow is looked up and the response
depends on the status:
  - if the status is not 'SUCCESS' or 'FAILURE', the request is still
    pending, and a corresponding message is returned to the SCEP client.
  - if the status is 'SUCCESS', the certificate is extracted from the
    workflow and returned to the SCEP client.
  - if the status is 'FAILURE' and the retry interval has not elapsed,
    the failure code is extracted from the workflow and returned to
    the client.
  - if the status is 'FAILURE' and the retry interval has elapsed,
    the failed workflow is unlinked from this transaction id and a
    new one is started

=cut

sub __pkcs_req : PRIVATE {
    my $self      = shift;
    my $arg_ref   = shift;
    my $api       = CTX('api');
    my $pki_realm = CTX('session')->data->pki_realm;
    my $profile   = CTX('session')->data->profile;
    my $server    = CTX('session')->data->server;

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

    Log::Log4perl::MDC->put('sceptid', $transaction_id);

    CTX('log')->application()->info("SCEP incoming request, id $transaction_id");


    my $workflow_id = 0;
    my $wf_info; # filled in either one of the branches

    # Search transaction id in datapool
    my $res = CTX('api')->get_data_pool_entry({
        NAMESPACE => 'scep.transaction_id',
        KEY => "$server:$transaction_id",
    });
    if ($res) {
        # Congrats - we got a race condition
        if ($res->{VALUE} !~ m{ \A \d+ \z }x) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_PARALLEL_REQUESTS_DETECTED",
                params => {
                    SERVER => $server,
                    TRANSACTION_ID => $transaction_id,
                    DPSTATE => $res->{VALUE}
                }
            );
        }
        $workflow_id = $res->{VALUE};
    }

    ##! 16: "transaction ID: $transaction_id - workflow id: $workflow_id"

    if ( $workflow_id ) {

        # Fetch the workflow
        $wf_info = $api->get_workflow_info({
            ID       => $workflow_id,
        });

        CTX('log')->application()->info("SCEP incoming request, found workflow $workflow_id, state " . $wf_info->{WORKFLOW}->{STATE});


    } else {

        ##! 16: "no workflow was found, creating a new one"

        # get workflow type and profile from config layer
        my $workflow_type = CTX('config')->get(['scep', $server, 'workflow_type']);

        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_NO_WORKFLOW_TYPE_DEFINED",
            params => {
                SERVER => $server,
                REALM =>  $pki_realm
            }
        ) unless($workflow_type);



        CTX('log')->application()->info("SCEP try to start new workflow for $transaction_id");


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

        # preregister the datapool key to prevent
        # race conditions with parallel workflows
        eval {
            # prepare the registration record - this will fail if the
            # request ran into a race condition
            CTX('api')->set_data_pool_entry({
                NAMESPACE => 'scep.transaction_id',
                KEY => "$server:$transaction_id",
                VALUE => 'creating',
                EXPIRATION_DATE => time() + 300, # Creating the workflow should never take any longer
            });
            # As the API does NOT commit to the datapool, we need an explicit commit now
            CTX('dbi')->commit();
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_FAILED_TO_REGISTER_SCEP_TID",
                params => {
                    SERVER => $server,
                    TRANSACTION_ID => $transaction_id,
                }
            );
        }

        $wf_info = $api->create_workflow_instance({
                WORKFLOW => $workflow_type,
                PARAMS   => {
                    'scep_tid'    => $transaction_id,
                    'signer_cert' => $signer_cert,
                    'pkcs10'         => $pkcs10,

                    #'expires' => $expirydate->epoch(),

                    # getting the profile should be moved into the workflow
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
        $workflow_id = $wf_info->{WORKFLOW}->{ID};
        ##! 16: 'workflow_id: ' . $workflow_id

        CTX('log')->application()->info("SCEP started new workflow with id $workflow_id, state " . $wf_info->{WORKFLOW}->{STATE});


        # Record the scep tid and the workflow in the datapool
        CTX('api')->set_data_pool_entry({
            NAMESPACE => 'scep.transaction_id',
            KEY => "$server:$transaction_id",
            VALUE => $workflow_id,
            FORCE => 1,
         });
         # commit required
         CTX('dbi')->commit();
    }

    # We should now have a workflow object,
    # either a reloaded or a freshly created one

    ##! 64: 'wf_info ' . Dumper $wf_info

    my $wf_state = $wf_info->{WORKFLOW}->{STATE};

    ##! 16: 'Workflow state ' . $wf_state

    my @extra_header = ( "X-OpenXPKI-WorkflowId: " . $wf_info->{WORKFLOW}->{ID} );

    if ( $wf_state ne 'SUCCESS' && $wf_state ne 'FAILURE' ) {
        CTX('log')->application()->info("SCEP $workflow_id in state $wf_state, send pending reply");


        # we are still pending
        my $pending_msg = $token->command(
            {   COMMAND  => 'create_pending_reply',
                PKCS7    => $pkcs7_decoded,
                HASH_ALG => CTX('session')->data->hash_alg,
            }
        );

        if ($wf_info->{WORKFLOW}->{CONTEXT}->{'error_code'}) {
            push @extra_header, "X-OpenXPKI-Error: " . $wf_info->{WORKFLOW}->{CONTEXT}->{'error_code'};
        }

        return [ \@extra_header, $pending_msg ];
    }

    if ( $wf_state eq 'SUCCESS' ) {
        # the workflow is finished,
        # get the certificate from the workflow

        my $cert_identifier = $wf_info->{WORKFLOW}->{CONTEXT}->{'cert_identifier'};
        ##! 32: 'cert_identifier: ' . $cert_identifier

        if (!$cert_identifier) {
            # Fallback for old workflows
            my $csr_serial = $wf_info->{WORKFLOW}->{CONTEXT}->{'csr_serial'};
            ##! 32: 'csr serial ' . $csr_serial

            my $csr_result = $api->search_cert({ CSR_SERIAL => $csr_serial });
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_CSR_SERIAL_FALLBACK_FAILED'
            ) if (ref $csr_result ne 'ARRAY' || scalar @{ $csr_result } != 1);

            $cert_identifier = $csr_result->[0]->{IDENTIFIER};

        }

        if (!$cert_identifier) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_CERT_IDENTIFIER_MISSING'
            );
        }

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
                ENCRYPTION_ALG => CTX('session')->data->enc_alg,
                HASH_ALG       => CTX('session')->data->hash_alg,
            }
        );

        CTX('log')->application()->info("Delivered certificate via SCEP ($cert_identifier)");


        return [ '', $certificate_msg ];
    }

    ##! 32: 'FAILURE'
    # must be one of the error codes defined in the SCEP protocol
    my $scep_error_code = $wf_info->{WORKFLOW}->{CONTEXT}->{'scep_error'};

    if ( !defined $scep_error_code || ($scep_error_code !~ m{ badAlg | badMessageCheck | badTime | badCertId }xms)) {
        CTX('log')->application()->error("SCEP Request failed without error code set - default to badRequest");

        $scep_error_code = 'badRequest';
    } else {
        CTX('log')->application()->error("SCEP Request failed with error $scep_error_code");

    }
    my $error_msg = $token->command(
        {   COMMAND      => 'create_error_reply',
            PKCS7        => $pkcs7_decoded,
            HASH_ALG     => CTX('session')->data->hash_alg,
            'ERROR_CODE' => $scep_error_code,
        }
    );

    if ($wf_info->{WORKFLOW}->{CONTEXT}->{'error_code'}) {
        push @extra_header, "X-OpenXPKI-Error: " . $wf_info->{WORKFLOW}->{CONTEXT}->{'error_code'};
    }


    return [ \@extra_header, $error_msg ];
}

1;    # magic one at the end of module
__END__


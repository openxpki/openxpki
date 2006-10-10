## OpenXPKI::Service::SCEP::Command::PKIOperation
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision: 235 $
##
package OpenXPKI::Service::SCEP::Command::PKIOperation;

use English;

use Class::Std;

use base qw( OpenXPKI::Service::SCEP::Command );

use OpenXPKI::Debug 'OpenXPKI::Service::SCEP::Command::PKIOperation';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::TokenManager;
use Data::Dumper;
use MIME::Base64;

sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;
    my $result;
    
    my $pkcs7_base64 = $self->get_PARAMS()->{MESSAGE};
    my $pkcs7_decoded = decode_base64($pkcs7_base64);
    
    my $api = CTX('api');
    my $pki_realm = CTX('session')->get_pki_realm();

    # get a new crypto token of type 'SCEP'
    my $token_manager = OpenXPKI::Crypto::TokenManager->new();
    my $token = $token_manager->get_token(
        TYPE      => 'SCEP',
        ID        => 'testscepserver1', # TODO: this is the name used in the config file, get from there!
        PKI_REALM => $pki_realm,
    ); 
    
    my $message_type_ref = $token->command({
        COMMAND => 'get_message_type',
        PKCS7   => $pkcs7_decoded,
    });

    if ($message_type_ref->{MESSAGE_TYPE_NAME} eq 'PKCSReq') {
        $result = $self->__pkcs_req({
            TOKEN => $token,
            PKCS7 => $pkcs7_base64,
        });
    }
    # elsif ...
    else {
        OpenXPKI::Exception->throw({
            message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_UNSUPPORTED_MESSAGE_TYPE',
            # TODO: once all are implemented, change to INVALID_M_T?
            params  => {'MESSAGE_TYPE' => $message_type},
        });
    }
    
    $result = "Content-Type: application/x-pki-message\n\n" . $result;
    return $self->command_response($result);
}

sub __pkcs_req : PRIVATE {
    my $self = shift;
    my $arg_ref = shift;
    my $api = CTX('api');
    
    my $pkcs7_base64  = $arg_ref->{PKCS7};
    my $pkcs7_decoded = decode_base64($pkcs7_base64);
    my $token         = $arg_ref->{TOKEN};
    
    my $transaction_id = $token->command({
        COMMAND => 'get_transaction_id',
        PKCS7   => $pkcs7_decoded,
    });

    ##! 16: "transaction ID: $transaction_id"
    # get workflow instance IDs corresponding to transaction ID
    my $workflows = $api->search_workflow_instances({
            CONTEXT => [
                {
                    KEY   => 'SCEP_TID',
                    VALUE => $transaction_id,
                },
            ],
    });
    my @workflow_ids = map { $_->{'WORKFLOW_CONTEXT.WORKFLOW_SERIAL'} } @{$workflows};
    # TODO: check if this works as before
    
    if (defined @workflow_ids) { # query status of workflow(s)
        ##! 16: "at least one workflow was found"
        my $num_of_workflows = scalar @workflow_ids;
        if ($num_of_workflows > 1) { # this should _never_ happen ...
            OpenXPKI::Exception->throw(
                message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_MORE_THAN_ONE_WORKFLOW_FOUND",
                params  => {
                    WORKFLOWS => $num_of_workflows,
                }
            );
        }
        else { # everything is fine, we have only one matching workflow
            my $wf_info = $api->get_workflow_info({
                WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                ID       => $workflow_ids[0],
            });
            my $wf_state = $wf_info->{WORKFLOW}->{STATE};
            if ($wf_state ne 'FINISHED') { # we are still pending
                my $pending_msg = 'PENDING'; # TODO: create real pending message
#                my $pending_msg = $token->command({
#                    COMMAND => 'scep_create_pending_reply',
#                    PKCS7   => $pkcs7_content,
#                });
#  $ENV{scep}
#  openca-scep -new -signcert $scep_cert -msgtype CertRep -status PENDING -keyfile $scep_key -passin env:pwd -in $p7_file -reccert $reccert_file -outform DER 
# why is -reccert needed?
                return $pending_msg;
            }
            else { # the workflow is finished, TODO: extract the certificate
                   # and return it to the requester
            }
        }
    }
    else { # create a new workflow instance
        ##! 16: "no workflow was found, creating a new one"
        $api->create_workflow_instance({
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
            PARAMS   => {
                PKCS7_CONTENT => $pkcs7_base64,
                SCEP_TID      => $transaction_id,
            }
        });
        return 'no workflows found';
    }
}

1; # magic one at the end of module
__END__

=head1 Name

OpenXPKI::Service::SCEP::Command::PKIOperation

=head1 Description

Implements the functionality required to answer SCEP PKIOperation messages.

=head1 Functions

=head2 execute

Parses the PKCS#7 container for the message type, calls a function
depending on that type and returns the result, including the HTTP
header needed for the scep CGI script.

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
  - if the status is not 'FINISHED', the request is still pending, and a
    corresponding message is returned to the SCEP client.
  - if the status is 'FINISHED', the certificate is extracted from the workflow
    and returned to the SCEP client.


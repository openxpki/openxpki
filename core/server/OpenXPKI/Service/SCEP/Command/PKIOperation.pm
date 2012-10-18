## OpenXPKI::Service::SCEP::Command::PKIOperation
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
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
use DateTime::Format::DateParse;

sub execute {
    my $self    = shift;
    my $arg_ref = shift;
    my $ident   = ident $self;
    my $result;
    
    my $pkcs7_base64 = $self->get_PARAMS()->{MESSAGE};
    ##! 64: 'pkcs7_base64: ' . $pkcs7_base64
    my $pkcs7_decoded = decode_base64($pkcs7_base64);
    
    my $api = CTX('api');
    my $pki_realm = CTX('session')->get_pki_realm();
    my $server = CTX('session')->get_server();

    ##! 16: 'pki_realm scep: ' . Dumper(CTX('pki_realm')->{$pki_realm}->{scep})

    # get a crypto token of type 'SCEP'
    my $token = CTX('pki_realm')->{$pki_realm}->{scep}->{id}->{$server}->{crypto};
    
    if (!defined $token) {
        ##! 64: Dumper CTX('pki_realm')->{$pki_realm}->{scep}
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_SCEP_TOKEN_MISSING',
        );
    }
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
    elsif ($message_type_ref->{MESSAGE_TYPE_NAME} eq 'GetCertInitial') {
        # used by sscep after sending first request for polling
        $result = $self->__pkcs_req({
            TOKEN => $token,
            PKCS7 => $pkcs7_base64,
        });
    }
    else {
        $result = $token->command({
            COMMAND      => 'create_error_reply',
            PKCS7        => $pkcs7_decoded,
            'ERROR_CODE' => 'badRequest',
        });
    }
    
    $result = "Content-Type: application/x-pki-message\n\n" . $result;
    return $self->command_response($result);
}

sub __pkcs_req : PRIVATE {
    my $self = shift;
    my $arg_ref = shift;
    my $api = CTX('api');
    my $pki_realm = CTX('session')->get_pki_realm();
    my $server    = CTX('session')->get_server();
    
    my $pkcs7_base64  = $arg_ref->{PKCS7};
    ##! 64: 'pkcs7_base64: ' . $pkcs7_base64
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
                    KEY   => 'scep_tid',
                    VALUE => $transaction_id,
                },
            ],
    });
    ##! 16: 'workflows: ' . Dumper $workflows
    my $failure_retry;
    if (scalar @{ $workflows } > 0) {
        if ($workflows->[0]->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE') {
            # the last workflow is in FAILURE, check the last update
            # date to see if user is already allowed to retry
            my $last_update
                = $workflows->[0]->{'WORKFLOW.WORKFLOW_LAST_UPDATE'};
            ##! 16: 'FAILURE workflow found, last update: ' . $last_update
            my $last_update_dt = DateTime::Format::DateParse->parse_datetime($last_update, 'UTC');
            ##! 32: 'last update dt: ' . Dumper $last_update_dt
            
            # determine retry time from config
            my $retry_time = CTX('pki_realm')->{$pki_realm}->{scep}->{id}->{$server}->{'retry_time'};
            if (! defined $retry_time) {
                $retry_time = '000001'; # default is one day
            }
            ##! 16: 'retry time: ' . $retry_time

            my $retry_date = OpenXPKI::DateTime::get_validity({
                REFERENCEDATE  => DateTime->now(),
                VALIDITY       => '-' . $retry_time,
                VALIDITYFORMAT => 'relativedate',
            });
            ##! 32: 'retry_date: ' . Dumper $retry_date
            if (DateTime->compare($last_update_dt, $retry_date) == -1) {
                ##! 64: 'last update is earlier than retry date, allow creation of new WF'
                # set DB result to empty, so that it looks like no wf is present
                $workflows = [ ];
            }
            else {
                ##! 64: 'last update is later than retry date, do not allow creation of new WF'
                # only include the first FAILURE wf in the result -> SCEP failure response
                $workflows = [ $workflows->[0] ];
            }
        }
    }
    if (scalar @{ $workflows } > 1) {
        # if more than one workflow is present, we delete the FAILURE ones
        # from it
        my @no_fail_workflows = grep { $_->{'WORKFLOW.WORKFLOW_STATE'} ne 'FAILURE' } @{ $workflows };
        $workflows = \@no_fail_workflows;
    }
    ##! 16: 'workflows after retry checking: ' . Dumper $workflows

    my @workflow_ids = map { $_->{'WORKFLOW.WORKFLOW_SERIAL'} } @{$workflows};
    
    if (scalar @workflow_ids == 0) { 
        ##! 16: "no workflow was found, creating a new one"
        my $profile = CTX('session')->get_profile();
        my $server  = CTX('session')->get_server();
        # inject newlines if not already present
        # this is necessary for openssl / openca-scep to parse
        # the data correctly
        ##! 64: 'pkcs7_base64 before sanitizing: __START__' . $pkcs7_base64 . '__END__'
        $pkcs7_base64 =~ s{ \n }{}xmsg;
        my $divides64;
        ##! 64: 'length: ' . length($pkcs7_base64)
        if (length($pkcs7_base64) % 64 == 0) {
            $divides64 = 1;
        }
        $pkcs7_base64 =~ s{ (.{64}) }{$1\n}xmsg;
        if (! $divides64) {
            ##! 64: 'pkcs7 length does not divide 64, add an additional newline'
            $pkcs7_base64 .= "\n";
        }
        ##! 64: 'pkcs7_base64 before create_wf_instance: ' . $pkcs7_base64
        my $wf_info = $api->create_workflow_instance({
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
            PARAMS   => {
                'pkcs7_content' => $pkcs7_base64,
                'scep_tid'      => $transaction_id,
                'cert_profile'  => $profile,
                'server'        => $server,
            }
        });
        ##! 16: 'wf_info: ' . Dumper $wf_info
        $workflow_ids[0] = $wf_info->{WORKFLOW}->{ID};
        ##! 16: '@workflow_ids: ' . Dumper \@workflow_ids
    }

    ##! 16: "at least one workflow was found"
    my $num_of_workflows = scalar @workflow_ids;
    if ($num_of_workflows > 1) { # this should _never_ happen ...
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_MORE_THAN_ONE_WORKFLOW_FOUND",
            params  => {
                WORKFLOWS      => $num_of_workflows,
                TRANSACTION_ID => $transaction_id,
            }
        );
    }
    else { # everything is fine, we have only one matching workflow
        my $wf_id = $workflow_ids[0];
        my $wf_info = $api->get_workflow_info({
            WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
            ID       => $wf_id,
        });
        my $wf_state = $wf_info->{WORKFLOW}->{STATE};
        if ($wf_state eq 'WAITED_FOR_CHILD') {
            # TODO - this is legacy code that can possbily removed, the 'WAITED_FOR_CHILD'
            # state is no longer present
            #
            # in this state, we have to look for an available activity
            # and execute it. This effectively checks whether the
            # certificate issuance is finished or not
            my $activities = $api->get_workflow_activities({
                WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                ID       => $wf_id,
            });
            ##! 32: 'activities: ' . Dumper $activities
            if (defined $activities && scalar @{$activities} > 1) {
                # this should _never_ happen
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_MORE_THAN_ONE_ACTIVITY_FOUND',
                );
            }
            elsif (defined $activities && scalar @{$activities} == 1) {
                # execute possible activity
                $api->execute_workflow_activity({
                    WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                    ID       => $wf_id,
                    ACTIVITY => $activities->[0],
                });
                # get new info and state
                $wf_info = $api->get_workflow_info({
                    WORKFLOW => 'I18N_OPENXPKI_WF_TYPE_SCEP_REQUEST',
                    ID       => $wf_id,
                });
                $wf_state = $wf_info->{WORKFLOW}->{STATE};
                ##! 16: 'new state after triggering activity: ' . $wf_state
            }        
        }
        my $waiting_for_child_success; # indicates whether WAITING_FOR_CHILD should 
                                       # actually be 'SUCCESS'
        my $waiting_for_child_failure; # indicates whether WAITING_FOR_CHILD should 
                                       # actually be 'FAILURE'
        my $waiting_for_child_pending; # indicates whether WAITING_FOR_CHILD should 
                                       # actually be 'PENDING'
        if ($wf_state eq 'WAITING_FOR_CHILD') {
            # if issuance stops for some reason (CA key not usable, for example),
            # the workflow sometimes "stops" in this state.
            # find out whether the workflow child is in state 'SUCCESS' or 'FAILURE'
            # or something else and delieve the corresponding response

            my $wf_children_instances = $wf_info->{WORKFLOW}->{CONTEXT}->{'wf_children_instances'};
            ##! 16: 'wf_children_instances: ' . $wf_children_instances;
            
            my $children = OpenXPKI::Serialization::Simple->new()->deserialize($wf_children_instances);
            my $child_id   = $children->[0]->{ID};
            my $child_type = $children->[0]->{TYPE};
            my $info = $api->get_workflow_info({
                WORKFLOW => $child_type,
                ID       => $child_id,
            });
            ##! 16: 'info: ' . Dumper $info
            if ($info->{WORKFLOW}->{STATE} eq 'SUCCESS') {
                $waiting_for_child_success = 1;
            }
            elsif ($info->{WORKFLOW}->{STATE} eq 'FAILURE') {
                $waiting_for_child_failure = 1;
            }
            else {
                $waiting_for_child_pending = 1;
            }
        }
        if ($wf_state ne 'SUCCESS' && $wf_state ne 'FAILURE' && ($wf_state ne 'WAITING_FOR_CHILD' || $waiting_for_child_pending)) {
            # we are still pending
            my $pending_msg = $token->command({
                COMMAND => 'create_pending_reply',
                PKCS7   => $pkcs7_decoded,
            });
            return $pending_msg;
        }
        if ($wf_state eq 'SUCCESS' || $waiting_for_child_success) { # the workflow is finished,
            # get the CSR serial from the workflow
            my $csr_serial = $wf_info->{WORKFLOW}->{CONTEXT}->{'csr_serial'};
            ##! 32: 'csr_serial: ' . $csr_serial

            my $search_result = $api->search_cert({
                CSR_SERIAL => $csr_serial,
            });
            ##! 32: 'search result: ' . Dumper $search_result
            if (ref $search_result ne 'ARRAY') {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_SEARCH_CERT_NO_ARRAYREF',
                );
            }
            if (scalar @{ $search_result } != 1) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_SEARCH_CERT_NOT_ONLY_ONE_RESULT',
                    params  => {
                        RESULTS => scalar @{ $search_result },
                    }
                );
            }
            my $cert_identifier = $search_result->[0]->{IDENTIFIER};

            my $certificate = $api->get_cert({
                IDENTIFIER => $cert_identifier,
                FORMAT     => 'PEM',
            });
            ##! 16: 'certificate: ' . $certificate

            if (! defined $certificate) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_GET_CERT_FAILED',
                    params => {
                        IDENTIFIER => $cert_identifier,
                    }
                );
            }

            my $certificate_msg = $token->command({
                COMMAND        => 'create_certificate_reply',
                PKCS7          => $pkcs7_decoded,
                CERTIFICATE    => $certificate,
                ENCRYPTION_ALG => CTX('session')->get_enc_alg(),
            });

            CTX('log')->log(
                MESSAGE  => "Delivered certificate via SCEP ($cert_identifier)",
                PRIORITY => 'info',
                FACILITY => 'system',
            );

            return $certificate_msg;
        }
        else { ##! 32: 'FAILURE'
            my $error_code = $wf_info->{WORKFLOW}->{CONTEXT}->{'error_code'};
            if (! defined $error_code) {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVICE_SCEP_COMMAND_PKIOPERATION_FAILURE_BUT_NO_ERROR_CODE',
                );
            }
            my $error_msg = $token->command({
                COMMAND      => 'create_error_reply',
                PKCS7        => $pkcs7_decoded,
                'ERROR_CODE' => $error_code,
            });
            return $error_msg;
        }
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
  - if the status is not 'SUCCESS' or 'FAILURE', the request is still
    pending, and a corresponding message is returned to the SCEP client.
  - if the status is 'SUCESS', the certificate is extracted from the
    workflow and returned to the SCEP client.
  - if the status is 'FAILURE', the failure code is extracted from the
    workflow and returned to the client


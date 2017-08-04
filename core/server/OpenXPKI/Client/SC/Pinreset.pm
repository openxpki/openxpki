=head1 NAME

OpenXPKI::Client::SC::Pinreset

=cut

package OpenXPKI::Client::SC::Pinreset;

use strict;
use Moose;
use English;
use Data::Dumper;
#use Crypt::CBC;
#use MIME::Base64;

extends 'OpenXPKI::Client::SC::Result';

=head2 handle_start_pinreset

=head3 parameters

=over

=item email1, email2

eMail Addresses of the authorising persons

=item unblock_wfID (optional)

Id of an existing unblock workflow, if not given, a new one is started

=back

=head3 response

=over

=item unblock_wfID

=item auth1_ldap_mail, auth2_ldap_mail

=back

=cut

sub handle_start_pinreset {

    my $self = shift;
    my $result;

    my $cardData = $self->cardData();

    my $log = $self->logger();
    $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_STARTRESET_CALL");

    my $wf_info;
    my $wf_type = $self->config()->{workflow}->{pinunblock};

    my $wf_id = $self->param("unblock_wfID");
    if ( !$wf_id || ($wf_id !~ /^[0-9]+$/ )) {
         $wf_id = 0;
    }

    my $email1 = $self->param("email1");
    my $email2 = $self->param("email2");

    if ( !$email1 ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_MISSING_PARAMETER_EMAIL1");
    }
    if ( !$email2 ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_MISSING_PARAMETER_EMAIL2");
    }

    if ($self->has_errors()) {
        return 1;
    }


    if ( $wf_id ) {
        $log->info( 'Existing Unblock workflow id ' .  $wf_id  );

        eval {
            $wf_info = $self->_client->handle_workflow( { ID => $wf_id } );
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_REINITIALIZE_WORKFLOW");
            return 1;
        }

        # Final state
        if ( $wf_info->{PROC_STATE} eq 'finished' ) {
            $log->warn( 'Unblock workflow is in final state, removing' );
            $wf_id = 0;
            $wf_info = undef;
        }

    }

    # No workflow given or given workflow in final state, create new
    if (!$wf_info) {
        eval {
            $wf_info = $self->_client->handle_workflow({
                'TYPE' => $wf_type,
                'PARAMS'   => {
                    token_id => $cardData->{'id_cardID'},
                }
            });
            $wf_id = $wf_info->{ID};
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_CREATE_WORKFLOW_INSTANCE");
            return 1;
        }
    }

    # Reset the auth persons, so we run an initialize before
    if ($wf_info->{STATE} eq 'PEND_ACT_CODE') {

        eval {
            $wf_info = $self->_client->handle_workflow({
                'ID'       => $wf_id,
                'ACTIVITY' => 'scunblock_initialize'
            });
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_REINIT_WORKFLOW");
            return 1;
        }
    }

    if ($wf_info->{STATE} ne 'HAVE_TOKEN_OWNER' ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STATE_HAVE_TOKEN_OWNER_REQUIRED");
        return 1;
    }

    # Store mail addresses in context
    my $params = {
        'ID'       => $wf_id,
        'ACTIVITY' => 'scunblock_store_auth_ids',
        'PARAMS'   => {
            auth1_id => $email1,
            auth2_id => $email2
        }
    };

    eval {
        $wf_info = $self->_client->handle_workflow($params);
    };
    if ($EVAL_ERROR) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STORE_AUTH_IDS");
        return 1;
    }

    $result = {
        'unblock_wfID' => $wf_id,
        'auth1_ldap_mail' => $wf_info->{CONTEXT}->{auth1_mail},
        'auth2_ldap_mail' => $wf_info->{CONTEXT}->{auth2_mail}
    };

    if ($wf_info->{STATE} ne 'PEND_ACT_CODE') {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STATE_PAND_ACT_CODE_REQUIRED");
    }

    $self->_result( $result );

    return 0;

}


=head2 handle_pinreset_verify

=head3 parameters

=over

=item activationCode1, activationCode2

Authorisation codes obtained from the contact persons.

=item unblock_wfID

Id of the unblock workflow

=back

=head3 response

=over

=item unblock_wfID

=item wfstate

=item exec

encrypted reset card command

=back

=cut

sub handle_pinreset_verify {

    my $self = shift;
    my $result;

    my $cardData = $self->cardData();

    my $log = $self->logger();
    $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_RESET_VERIFY_CALL");

    my $wf_info;
    my $wf_id = $self->param("unblock_wfID");
    my $code1 = $self->param("activationCode1");
    my $code2 = $self->param("activationCode2");


   if ( !$wf_id ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_WF_ID");
    }

    if ( !$code1 ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_ACTIVATIONCODE1");
    }
    if ( !$code2  ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_ACTIVATIONCODE2");
    }

    if ($self->has_errors()) {
        return 1;
    }

    eval {
        $wf_info = $self->_client->handle_workflow( { ID => $wf_id } );
    };
    if ($EVAL_ERROR) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_WF_FAILURE");
        return 1;
    }

    my $wf_state = $wf_info->{STATE};

    if ( $wf_state eq 'FAILURE' ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_WF_FAILURE");
        return 1;
    }

    $log->info('Current state is ' . $wf_state );

    if ( $wf_state eq 'PEND_PIN_CHANGE' ) {

        eval {
            $wf_info = $self->_client->handle_workflow( {
                ID => $wf_id,
                'ACTIVITY' => 'scunblock_post_codes',
                'PARAMS'   => {
                    _auth1_code => $code1,
                    _auth2_code => $code2,
                }
            });
            $wf_state = $wf_info->{STATE};
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_POST_CODES_FAILED");
            return 1;
        }

        # Most likely the codes are wrong
        if ($wf_state ne 'CAN_FETCH_PUK') {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_AUTHCODES_INCORRECT");
            return 1;
        }

    }

    if ($wf_state eq 'CAN_FETCH_PUK') {

        my $_puk;
        eval {
            $wf_info = $self->_client->handle_workflow( {
                ID => $wf_id,
                'ACTIVITY' => 'scunblock_fetch_puk',
            });
            $wf_state = $wf_info->{STATE};
            my $_puks = $wf_info->{CONTEXT}->{_puk};
            $_puk = $self->serializer()->deserialize( $_puks ) if ($_puks);
        };
        if ($EVAL_ERROR || !$_puk ) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_FETCH_PUK_FAILED");
            return 1;
        }

        my $plugincommand =
            'ResetPIN;CardSerial='. $cardData->{'cardID'} . ';PUK='. $_puk->[0] . ';';

        eval {
            $result->{'exec'} = $self->session_encrypt($plugincommand);
        };

    }

    $result->{'unblock_wfID'} = $wf_id;
    $result->{'wfstate'} = $wf_state;

    $self->_result($result);

    return 0;


}


=head2 handle_pinreset_confirm

=head3 parameters

=over

=item unblock_wfID

=item Result

Result status word from the card reader

=item Reason (optional)

Reason if operation failed

=back

=head3 response

=over

=item unblock_wfID

=item wfstate

=back

=cut

sub handle_pinreset_confirm {

    my $self = shift;

    my $log = $self->logger();

    my $wf_info;
    my $wf_type = $self->config()->{workflow}->{unblock};
    my $wf_id = $self->param("unblock_wfID");
    my $ui_result = $self->param("Result");
    my $ui_reason = $self->param("Reason") || '';

    if (!$wf_id) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_MISSING_PARAMETER_WF_ID");
        return 1;
    }

    if ( !$ui_result ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_MISSING_PARAMETER_RESULT");
    }

    eval {
        if ( $ui_result eq "SUCCESS" ) {

            $wf_info = $self->_client->handle_workflow( {
                ID => $wf_id,
                'ACTIVITY' => 'scunblock_write_pin_ok',
            });

        } else {
            $wf_info = $self->_client->handle_workflow( {
                ID => $wf_id,
                'ACTIVITY' => 'scunblock_write_pin_nok',
                'PARAMS' => { 'error_code' => $ui_reason }
            });
        }
    };
    if ($EVAL_ERROR) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_CHANGING_STATE");
        return 1;
    }

    $self->_result({ wfstate => $wf_info->{STATE} });

    return 1;

}


=head2 handle_pinreset_cancel

=head3 parameters

=over

=item unblock_wfID

=back

=head3 response

none

=cut
sub handle_pinreset_cancel {

    my $self = shift;

    my $log = $self->logger();

    my $wf_info;
    my $wf_type = $self->config()->{workflow}->{unblock};
    my $wf_id = $self->param("unblock_wfID");
    my $ui_result = $self->param("Result");
    my $ui_reason = $self->param("Reason") || '';

    if (!$wf_id) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_WF_ID");
        return 1;
    }
    eval {
        $wf_info = $self->_client->handle_workflow( {
            ID => $wf_id,
            'ACTIVITY' => 'scunblock_user_abort',
            'PARAMS' => { 'error_code' => 'user abort' }
        });
    };
    if ($EVAL_ERROR) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_CHANGING_STATE");
        return 1;
    }

    return 0;

}

1;

=head1 NAME

OpenXPKI::Client::SC::Changecardpolicy

=cut

package OpenXPKI::Client::SC::Changecardpolicy;

use strict;
use Moose;
use English;
use Data::Dumper;

extends 'OpenXPKI::Client::SC::Result';

=head2 handle_get_card_policy

Get the card command to enable/disable the PUK policy on the card.
Requires the aes key set in the session.

=head3 parameters

=over

=item disable

Set to the string I<true> to get the PUK disable command, all other values
will result in the PUK enable command.

=back

=head3 response

=over

=item changecardpolicy_wfID

=item exec

=back

=cut

sub handle_get_card_policy {

    my $self = shift;

    my $wf_type = $self->config()->{workflow}->{changecardpolicy};
    my $wf_id;
    my $wf_info;
    my $wf_state;

    my $session = $self->_session();
    my $cardData = $self->cardData();
    my $log = $self->logger();

    if ( ! $session->param('aeskey') ) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_ERROR_NO_SESSION_KEY");
        return 1;
    }

    eval {
        $wf_info = $self->_client->handle_workflow( {
            'TYPE' => $wf_type,
            'PARAMS'   => { token_id => $cardData->{'id_cardID'}, },
        });
        $wf_id = $wf_info->{ID};
        $wf_state = $wf_info->{STATE};
    };
    if ($EVAL_ERROR) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CREATE_WORKFLOW_INSTANCE");
        return 1;
    }

    my $_puks = $wf_info->{CONTEXT}->{_puk};

    if (!$_puks) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CREATING_WORKFLOW");
        return 1;
    }

    my $_puk = $self->serializer()->deserialize( $_puks );

    my $card_policy_string;
    if ( $self->param("disable") &&  $self->param("disable") eq 'true' ) {
        $card_policy_string = $self->config()->{card}->{b64cardPolicyOff};
        $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_DISABLE_TRUE");
    } else {
        $card_policy_string = $self->config()->{card}->{b64cardPolicyOn};
        $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_DISABLE_FALSE");
    }

    my $plugincommand = 'SetPINPolicy;CardSerial='
          . $cardData->{'cardID'} . ';PUK='
          . $_puk->[0]
          . ';B64Data='
          . $card_policy_string . ";";

    my $exec = $self->session_encrypt($plugincommand);

    $self->_result({
        'changecardpolicy_wfID' => $wf_id,
        'exec' => $exec
    });

    return 1;
}



=head2 handle_confirm_policy_change

=head3 parameters

=over

=item changecardpolicy_wfID

=item Result

Status word from the card plugin, I<SUCCESS> if ok, anything else if not.

=item Reason

Verbose reason in case of failure.

=back

=head3 response

=over

=item state

=back

=cut

sub handle_confirm_policy_change {

    my $self = shift;

    my $wf_info;

    my $log = $self->logger();

    my $wf_id = $self->param("changecardpolicy_wfID");
    my $ui_result = $self->param("Result");
    my $ui_reason = $self->param("Reason") || '';

    if (!$ui_result) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_NO_CHANGECARDPOLICY_RESULT");
        return 1;
    }

    eval {
        if ( $ui_result eq "SUCCESS" ) {

            $wf_info = $self->_client->handle_workflow( {
                ID => $wf_id,
                'ACTIVITY' => 'scfp_ack_fetch_puk',
            });

        } else {
            $wf_info = $self->_client->handle_workflow( {
                ID => $wf_id,
                'ACTIVITY' => 'scfp_puk_fetch_err',
                'PARAMS' => { 'error_reason' => $ui_reason }
            });
        }
    };
    if ($EVAL_ERROR) {
        $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CONFIRM_CHANGE_RESULT");
        return 1;
    }

    $self->_result({
        'state' => $wf_info->{STATE},
    });

    return 1;

}

1;

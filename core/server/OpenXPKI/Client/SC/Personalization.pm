=head1 NAME

OpenXPKI::Client::SC::Personalization

=cut

package OpenXPKI::Client::SC::Personalization;

use strict;
use Moose;
use English;
use Data::Dumper;
#use Crypt::CBC;
#use MIME::Base64;

extends 'OpenXPKI::Client::SC::Result';

=head2 handle_server_personalization

Main interface to personalization workflow, translates action commands
and parameters from the frontend to the backend workflow.

=head3 parameters

Parameters depend on the current state.

=over

=item wf_action

=item perso_wfID

=item cert0...cert15

=item PKCS10Request

=item KeyID

=item userAccount

=item Result

Status word from the card plugin, I<SUCCESS> if ok, anything else if not.

=item Reason

Verbose reason in case of failure.

=back

=head3 response

error
wf_state
perso_wfID
exec
action

=cut

sub handle_server_personalization {

    my $self = shift;

    my $wf_type = $self->config()->{workflow}->{personalization};
    my $keysize = $self->config()->{card}->{keysize} || 2048;
    my $session = $self->_session();

    my @certs;

    my $result = {};
    my $log = $self->logger();
    my $cardData = $self->cardData();

    # We try to install the PUK more than once as this fails sometime
    # this session value tracks the number of times we tried already
    # TODO - move this to the workflow
    my $puk_install_retry = $session->param('puk_install_retry') || 0;

    # this seems to be the result of the pkcs11 plugin operation (status word)
    my $ui_result = $self->param("Result") || '';
    # verbose message for ui result
    my $ui_reason = $self->param("Reason") || '';

    $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSO_CALL");

    # on reconnect error
    #"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI_SESSION_START_FAILED"


    # $responseData->{'found_wf_ID'} = $self->param("perso_wfID");


    my $wf_action = $self->param("wf_action") || '';
    my $wf_id;
    my $wf_state;

    if ($self->param("perso_wfID") && $self->param("perso_wfID") =~ /^([0-9]+)$/) {
        $wf_id = $1;
    }

  CERTS:
    for ( my $i = 0 ; $i < 15 ; $i++ ) {
        my $index = sprintf( "%02d", $i );
        last CERTS if !defined $self->param("cert$index");
        push( @certs, $self->param("cert$index") );
    }

    my $certsoncard = join( ';', @certs );

    my $wf_info;
    # no workflow id given, start new workflow
    if ( !defined $wf_id ) {

        my $params = {
            'TYPE' => $wf_type,
            'PARAMS'   => {
                'certs_on_card' => $certsoncard,
                #'user_id'       => '', # not used yet
                'token_id'      => $cardData->{'id_cardID'},
                'chip_id'       => $cardData->{'ChipSerial'},
            },
        };

        eval {
            $wf_info = $self->_client->handle_workflow( $params );
        };
        if (my $eval_err = $EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_CREATE_PERSONALIZATION_WORKFLOW");
            $log->error(sprintf('Unable to create workflow for card %s. EE: %s', $cardData->{'id_cardID'}, $eval_err));
            return 1;
        }

        $wf_id = $wf_info->{ID};
        $wf_state = $wf_info->{STATE};

        $log->info(sprintf('New workflow created for card %s, id %01d, state %s ',
            $cardData->{'id_cardID'}, $wf_id, $wf_state) );

        # Prereqs failed - workflow crashed finally
        if ($wf_state eq 'FAIULRE') {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_PERSONALIZATION_WORKFLOW_FAILED_ON_INIT");
            return 1;
        }


    }

    if ( $wf_action ) {
        $log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSONALIZATION_ACTION:"
              . $wf_action . " WFID_" . $wf_id );
    }

    ######################################################################
    ##
    ## Run actions on the workflow engine based on the wf_action parameter
    ##
    ######################################################################
    if ( $wf_action eq 'prepare' ) {

        if ( $ui_result eq 'SUCCESS' ) {

            if ( !$session->param('tmp_rndPIN') ) {
                $log->error('I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSONALIZATION_ERROR_INSTALLING_RNDPIN');
            } else {
                $log->debug('I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSONALIZATION_INSTALLED_RNDPIN');
                $session->param('rndPIN', $session->param('tmp_rndPIN') );
            }

        } else {
            $log->error( sprintf("Plugin action %s failed: %s / %s" , $wf_action, $ui_result, $ui_reason ));
        }

    }
    elsif ( $wf_action eq 'select_useraccount' ) {

        my $user = $self->param("userAccount");

        if (!$user) {
            $self->_add_error("Plugin called select_useraccount without passing account name!");
            return 1;
        }

        my $params = {
            'ID'       => $wf_id,
            'ACTIVITY' => 'scpers_apply_csr_policy',
            'PARAMS'   => {
                'login_ids' => $self->serializer()->serialize( [ $user ] )
            }
        };

        $log->debug('Execute select_useraccount');
        $log->trace('Parameters: ' . Dumper $params );

        eval {
            $wf_info = $self->_client->handle_workflow( $params );
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_APPLY_CSR_POLICY");
            return 1;
        }
    }
    elsif ( $wf_action eq 'install_puk' ) {

        # Plugin has installed the PUK on the card
        if ( $ui_result eq 'SUCCESS' ) {

            my $params = {
                'ID'       => $wf_id,
                'ACTIVITY' => 'scpers_puk_write_ok',
                'PARAMS'   => {},
            };

            eval {
                $wf_info = $self->_client->handle_workflow( $params );
            };
            if ($EVAL_ERROR) {
                $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_STATUS");
                return 1;
            }
            $log->info("install PUK was successful");

        # In case a prior PUK change failed, we try again with the old PUK
        } elsif ( $puk_install_retry  == 1 ) {

            $log->warn("install PUK failed, try one more time ");

            # PUK failed to install if it was the first try stay in the state and try one more time

        } else {

            $log->error( sprintf("Plugin action %s failed: %s / %s" , $wf_action, $ui_result, $ui_reason ));

            my $params = {
                'ID'       => $wf_id,
                'ACTIVITY' => 'scpers_puk_write_err',
                'PARAMS'   => { 'sc_error_reason' => 'FATAL PUK ERROR' },
            };
            eval {
                $wf_info = $self->_client->handle_workflow( $params );
            };
            if ($EVAL_ERROR) {
                $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_STATUS");
                return 1;
            }

        }
    }
    elsif ( $wf_action eq 'upload_csr' ) {

        my $pkcs10 = $self->param('PKCS10Request') || '';
        my $keyid = $self->param('KeyID') || '';

        $log->info("Plugin csr upload for keyid $keyid");

        #    $log->debug("choosen_login". $chosenLoginID);
        #    if ( defined $self->param('chosenLoginID') ) {
        #        $chosenLoginID = $self->param('chosenLoginID');
        #    }

        #    if( defined $session->param('dbntloginid') ){
        #        eval{
        #              $log->info("LoginID:". $session->param('dbntloginid'});
        #             # $log->info("LoginID:". Dumper($session->param('dbntloginid'})));
        #              $log->info("LoginID:". $session->param('dbntloginid')->{0});
        #        };
        #        ##FIXME Always use first ID regardless of number of ID'S
        #        $chosenLoginID = $session->param('dbntloginid')->[0];
        #    }


        # split line into 76 character long chunks
        $pkcs10 = join( "\n", ( $pkcs10 =~ m[.{1,64}]g ) );

        # add header
        $pkcs10 =
            "-----BEGIN CERTIFICATE REQUEST-----\n"
          . $pkcs10 . "\n"
          . "-----END CERTIFICATE REQUEST-----";

        $log->debug( "pkcs10: " .  $pkcs10 );

        my $params = {
            'ID'       => $wf_id,
            'ACTIVITY' => 'scpers_post_non_escrow_csr',
            'PARAMS'   => {
                'pkcs10' => $pkcs10,
                'keyid'  => $keyid,
                #        'chosen_loginid' => $chosenLoginID
            },
        };

        eval {
            $wf_info = $self->_client->handle_workflow( $params );
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR");
            return 1;
        }

        $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR");

    }
    elsif ( $wf_action eq 'install_cert' || $wf_action eq 'install_p12' ) {

        my $params = { 'ID' => $wf_id, 'PARAMS'   => {} };

        # Frontend was able to install certificate
        if ( $ui_result eq 'SUCCESS' ) {
            $params->{'ACTIVITY'} = 'scpers_cert_inst_ok';

        # Frontend had problems to install certificate
        } else {
            $params->{'ACTIVITY'} = 'scpers_cert_inst_err';
            $params->{'PARAMS'} = {'sc_error_reason' => $ui_reason };
            $log->error( sprintf("Plugin action %s failed: %s / %s" , $wf_action, $ui_result, $ui_reason ));
        }

        eval {
            $wf_info = $self->_client->handle_workflow( $params );
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK");
            return 1;
        }

    }
    elsif ( $wf_action eq 'delete_cert' ) {

        my $params = { 'ID' => $wf_id, 'PARAMS'   => {} };
        if ( $ui_result eq 'SUCCESS' ) {
            $params->{'ACTIVITY'} = 'scpers_cert_del_ok';
        } else {
            $params->{'ACTIVITY'} = 'scpers_cert_del_err';
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_SMARTCARD_ACTIVITY_CERT_INSTALL");
        }

        eval {
            $wf_info = $self->_client->handle_workflow( $params );
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_DEL_STATUS");
            return 1;
        }

    }

    # we need the wf_info to decide on the next steps, load if not set
    if (!$wf_info) {
        eval {
            $wf_info =  $self->_client->handle_workflow( { ID => $wf_id } );
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_FETCHING_WORKFLOW_INFO");
            return 1;
        }
        $log->debug('Fetch workflow info');
    }

    $log->trace('Workflow Info ' . Dumper $wf_info );

    $wf_state = $wf_info->{STATE};
    $result->{'perso_wfID'} = $wf_id;
    $result->{'wf_state'} = $wf_state;
    $self->_result( $result );

    ######################################################################
    ##
    ## check if the workflow has finished
    ##
    ######################################################################

    if ($wf_state eq 'SUCCESS') {
        $log->info(sprintf'Personalization workflow %01d for card %s finished with success', $wf_id, $cardData->{'id_cardID'} );
        return 0;
    }
    elsif ($wf_state eq 'FAILURE') {
        $log->info(sprintf'Personalization workflow %01d for card %s failed finally', $wf_id, $cardData->{'id_cardID'} );
        return 0;
    }

    $log->info(sprintf'Personalization workflow %01d for card %s now in state %s', $wf_id, $cardData->{'id_cardID'}, $wf_state );

    ######################################################################
    ##
    ## Assemble the next command for the pkcs11 plugin
    ##
    ######################################################################

    my $plugincommand;
    my $plugin_action;
    my $context = $wf_info->{CONTEXT};

    # a random pin already exists, so we can take care of installing data
    # onto the card. If no pin exists, we need to set one on the card first
    if (my $random_pin = $session->param('rndPIN')) {

        if ( $wf_state eq 'NEED_NON_ESCROW_CSR' ) {

            $plugin_action = 'upload_csr';

            $plugincommand =
                'GenerateKeyPair;CardSerial='
              . $cardData->{'cardID'}
              . ';UserPIN='
              . $random_pin
              . ';SubjectCN='
              . $context->{creator}
              . ';KeyLength='
              . $keysize . ';';

        }
        elsif ( $wf_state eq 'POLICY_INPUT_REQUIRED' ) {

            $plugin_action = 'select_useraccount';
            $plugincommand = 'NOCOMMAND';

        }
        elsif ( $wf_state eq 'CERT_TO_INSTALL' ) {

            $plugin_action = 'install_cert';

            $context->{certificate} =~ m{ -----BEGIN\ CERTIFICATE-----(.*?)-----END }xms;

            my $certificate_to_install = $1;
            $certificate_to_install =~ s{ \s }{}xgms;

            $plugincommand =
                'ImportX509;CardSerial='
              . $cardData->{'cardID'}
              . ';KeyID='
              . $context->{keyid}
              . ';UserPIN='
              . $random_pin
              . ';B64Data='
              . $certificate_to_install . ';';
        }
        elsif ( $wf_state eq 'HAVE_CERT_TO_DELETE' ) {

            $plugin_action = 'delete_cert';

            my $cert_to_delete_id = $context->{keyid};

            $plugincommand =
                'DeleteUserData;CardSerial='
              . $cardData->{'cardID'}
              . ';KeyID='
              . $cert_to_delete_id
              . ';UserPIN='
              . $session->param('rndPIN')
              . ';DeleteCert=true'
              . ';DeleteKeypair=true;';
        }
        elsif ( $wf_state eq 'PKCS12_TO_INSTALL' ) {

            $plugin_action = 'install_p12';

            if ( ! $context->{_pkcs12} ) {

                eval {
                    $wf_info = $self->_client->handle_workflow( {
                        'ID'       => $wf_id,
                        'ACTIVITY' => 'scpers_refetch_p12',
                        'PARAMS'   => {},
                    });
                    $result->{'wf_state'} = $wf_state;
                };
                if ($EVAL_ERROR) {
                    $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCH_P12_PW");
                    return 1;
                }
            }
            my $p12_pin = $wf_info->{CONTEXT}->{_password};
            my $p12 = $wf_info->{CONTEXT}->{_pkcs12};

            $plugincommand =
                'ImportP12;CardSerial='
              . $cardData->{'cardID'}
              . ';P12PIN='
              . $p12_pin
              . ';UserPIN='
              . $session->param('rndPIN')
              . ';B64Data='
              . $p12 . ';';

        }
    }

    # no pin in session, generate a new pin and set it on the card
    else {

        $log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_PERSONALIZATION_GET_PREPARE" );

        my $rnd;

        eval {
            my $count = 0;
            do {
                my $rndmsg = $self->_client()->run_command( 'get_random', { 'LENGTH' => 15 } );
                $rnd = lc( $rndmsg );
                $rnd =~ tr{[a-z0-9]}{}cd;
                $count++;
            } while ( length($rnd) < 8 && $count < 3 );
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN");
            return 1;
        }

        $rnd = substr( $rnd, 0, 8 );

        # in order to satisfy the smartcard pin policy even in
        # pathologic cases of the above random output generation we
        # append a semi-random digit and character to the pin string
        $rnd .= int( rand(10) );
        $rnd .= chr( 97 + rand(26) );
        $session->param('tmp_rndPIN',  $rnd );

        $log->info( "Fetch PUK to set new PIN for workflow " . $wf_id );

        eval {
            $wf_info = $self->_client->handle_workflow( {
                'ID'       => $wf_id,
                'ACTIVITY' => 'scpers_fetch_puk',
            });
            $result->{'wf_state'} = $wf_state;
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK");
            return 1;
        }

        my $PUK = $self->serializer()->deserialize( $wf_info->{CONTEXT}->{_puk} );

        # If this is a new card, we write a new PUK to the card
        if ($wf_info->{STATE} eq 'PUK_TO_INSTALL') {

            $log->info( "New card - install custom PUK " );

            if (scalar @{$PUK} == 1) {
                # if we have only one PUK, we fake a failed try
                $puk_install_retry = 1;
            }

            # try a PUK Change first
            $plugin_action     = 'install_puk';
            if ($puk_install_retry == 0)  {

                $session->param( 'puk_install_retry', 1 );
                $plugincommand =
                    'ChangePUK;CardSerial='
                    . $cardData->{'cardID'} . ';PUK='
                    . $PUK->[1]
                    . ';NewPUK='
                    . $PUK->[0] . ';';

            } elsif ($puk_install_retry == 1) {

                # First try with two PUKs failed

                $session->param( 'puk_install_retry', 2 );
                $plugincommand =
                    'ChangePUK;CardSerial='
                    . $cardData->{'cardID'} . ';PUK='
                    . $PUK->[1]
                    . ';NewPUK='
                    . $PUK->[0] . ';';

            } else {
                $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_PERSONALIZATION_PUK_TO_INSTALL_RECOVERY_TRY_2_FAILED");
                return 1;
            }
        # The default case, we have a PUK on card and set the new random PIN
        } else {

            $plugin_action = 'prepare';

            $plugincommand =
                'ResetPIN;CardSerial='
                . $cardData->{'cardID'} . ';PUK='
                . $PUK->[0]
                . ';NewPIN='
                . $rnd. ';';
        }

    }  # end no pin

    $log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_ENCRYPT_OUT_DATA" );

    # If we have a plugin command, encrypt it with the session key
    if ( $plugincommand ) {

        eval {
            $result->{'exec'} = $self->session_encrypt($plugincommand);
        };
        if ($EVAL_ERROR) {
            $self->_add_error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_PERSONALIZATION_FAILED_TO_ENCRYPT_COMMAND");
            return 1;
        }

        $result->{'action'} = $plugin_action;
        $log->info( 'Plugin action:' . $plugin_action );
    }

    $log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_OUT_DATA_ENCRYPTED" );

    #$result->{'perso_wf_type'} = $wf_type;

    $self->_result($result);

    $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSO_RETURN_RESPONSE");
    return 1;

}

1;


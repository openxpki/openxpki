## OpenXPKI::Client::HTML::SC::Getauthcode
##
## Written by Arkadius C. Litwinczuk 2010
## Copyright (C) 2010 by The OpenXPKI Project
package OpenXPKI::Client::HTML::SC::Getauthcode;

#common sense
use strict;
use warnings "all";

#use utf8;
use English;

use JSON;
use OpenXPKI::Client;

#use OpenXPKI::Tests;
use Config::Std;
use OpenXPKI::i18n qw( i18nGettext );
use Data::Dumper;
use OpenXPKI::Client::HTML::SC::Dispatcher qw( config );

use base qw(
  Apache2::Controller
  Apache2::Request
  OpenXPKI::Client::HTML::SC
);

use Apache2::Const -compile => qw( :http );

#Only these functions can be called via HTTP/Perlmod
sub allowed_methods {
    qw( getauthcode );
}    #only these fucntions can be called via handler

#Function get_auth_code
#Description: get auth code form pinreset workflow
#Required Parameter via HTTPRequest:
#		id				 			- Workflow ID
#		authuser					- from webSSO Request sent to Server
sub getauthcode {
    my ($self)        = @_;
    #my $sessionID     = $self->pnotes->{a2c}{session_id};
    #my $session       = $self->pnotes->{a2c}{session};
    my $responseData  = {};
    my $errors        = [];		#Error Array here we push occured erros 
    my $workflowtrace = [];		#Workflowtrace here we log successful operations will leter be send 

    #$session->{'errors'}        = $errors;
    #$session->{'workflowtrace'} = $workflowtrace;
    #$session->{'responseData'}  = $responseData;
    $responseData->{'error'}    = '';

    my $c;

    # DB WebSSO sets an environment variable according to the logged in user
    my $userid = $self->{r}->headers_in()->get('ct-remote-user');
    $responseData->{'userlogin'} = $userid;

    if ( !defined $userid || $userid eq '' ) {
        push(
            @{$errors},
'I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_GET_AUTH_CODE_WEBSSO_MISSING_USERNAME'
        );

        $responseData->{'error'}  = 'error';
        $responseData->{'errors'} = $errors;

        return $self->send_json_respond($responseData);

    }

    my $wf_type = config()->{openxpki}->{pinunblock};

#     if ( !defined $self->param("foruser") ) {
#         $responseData->{'error'} = "error";
#         push( @{$errors},
#             "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_GET_AUTH_CODE_ERROR_MISSING_PARAMETER_FORUSER"
#         );
#     }
#     else {
#         $session->{'foruser'}      = $self->param('foruser');
#         $responseData->{'foruser'} = $session->{'foruser'};
#     }
    if ( !defined $self->param("id") ) {
        $responseData->{'error'} = "error";
        push(
            @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_GET_AUTH_CODE_ERROR_MISSING_PARAMETER_ID"
        );
    }
    else {
         $responseData->{'wf_ID'}  = $self->param('id');
         #$responseData->{'wf_ID'} = $session->{'wf_ID'};
    }
    $c = $self->openXPKIConnection( undef ,
        $userid, 'user' );

    if ( !defined $c ) {

        # die "Could not instantiate OpenXPKI client. Stopped";
        #             $responseData->{'error'} = $responseData->{'error'}
        #               . "I18N_OPENXPKI_CLIENT_ERROR_CANT_CONNECT_TO_PKI";
        $responseData->{'error'} = "error";
        my $r = push(
            @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI"
        );

        #$self->print("Could not instantiate OpenXPKI client. Stopped");
    }
    else {
        if ( $c != 0 ) {
           # $session->{'openxPKI_Session_ID'} = $c->get_session_id();

            my $msg = $self->wf_status( $c,  $responseData->{'wf_ID'}, $wf_type );

            $responseData->{'msg'}  = $msg;

            if ( $msg eq
'I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATUS_ERROR_CANT_GET_WORKFLOW_INFO'
              )
            {
                $responseData->{'error'} = "error";
                push(
                    @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_GETAUTHCODE_ERROR_GET_WORKFLOW_INFO"
                );
            }
            else {
                push(
                    @{$workflowtrace},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_GETAUTHCODE_SUCCESS_WORKFLOW_INFO"
                );

                $responseData->{'wf_state'} =
                  $msg->{PARAMS}->{WORKFLOW}->{STATE};
                $responseData->{'foruser'} =
                  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{creator};
            }

            #$self->print("\nSession ". $c->get_session_id());
            #             $responseData->{'start_msg'} =
            #               "New SessionID:" . $c->get_session_id();

				if($responseData->{'wf_state'} eq 'SUCCESS' ||  $responseData->{'wf_state'} eq 'FAILIURE'){
                $responseData->{'error'} = "error";
                push(
                    @{$errors},
							"I18N_OPENXPKI_CLIENT_WEBAPI_SC_GETAUTHCODE_ERROR_WORKFLOW_FINISHED"
                );
					
				}

        }
        else {
            $responseData->{'error'} = "error";
            my $r = push(
                @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_GET_AUTH_CODE_ERROR_CANT_CONNECT_TO_PKI"
            );

        }

    }

	if(defined $responseData->{'error'} && $responseData->{'error'} ne "error"){
		
     	my $code =  $self->wftask_getcode( $c,  $responseData->{'wf_ID'}, $userid, '' );
     	
     	if( defined $code->{error} &&  $code->{error} eq 'error' )
     	{
      	    $responseData->{'error'} = "error";
            my $r = push(
                @{$errors},
				 pop(@{$code->{errors}})
            );
    	
      	}else{
      		$responseData->{'code'} = $code->{msg};
      	}
     
    }
     

    $responseData->{'errors'} = $errors;

    $responseData->{'workflowtrace'} = $workflowtrace;

    return $self->send_json_respond($responseData);

}

#Function wftask_getcode
#Description: retrive an Activationcode from active workflow in the correct state
#usage: my $code = wftask_getcode( ID, USER, PASS );
#Required Parameter
#		$id				- Workflow ID
#     $cleint  - openXPKIconnection
#		$u 		- WEBSSO user ?
# 		$p			- userpass
sub wftask_getcode {
    my ( $self, $client, $id, $u, $p ) = @_;

    my ( $ret, $msg );

    #  my $client;
    my $act    = 'scunblock_generate_activation_code';
    my $params = {};
    my $sleep;
    my $wf_type = config()->{openxpki}->{pinunblock};

    my $sessionID = $self->pnotes->{a2c}{session_id};
    my $session   = $self->pnotes->{a2c}{session};
# 
#    my $errors        = $session->{'errors'};
#    my $workflowtrace = $session->{'workflowtrace'};
#   my $responseData  = $session->{'responseData'};

    my $responseData  = {};
    my $errors        = [];		#Error Array here we push occured erros 
    $responseData->{'error'} = '';

    #   sleep 1 if $sleep;

    $msg =
      $client->send_receive_command_msg( 'get_workflow_info',
        { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
    if ( $self->is_error_response($msg) ) {

        $responseData->{'error'} = "error";
        push(
            @{$errors},
            "I18N_OPENXPKI_CLIENT_GETAUTHCODE_ERROR_GETTING_WORKFLOW_INFO"
        );
        push( @{$errors}, $msg );
    }
    sleep 1 if $sleep;

    unless ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'PEND_ACT_CODE'
        or $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'PEND_PIN_CHANGE' )
    {
        $responseData->{'error'} = "error";
        push(
            @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFTASK_GETCODE_ERROR_STATE_INVALID"
        );

        #return undef;
        #~ return
        #~ "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFTASK_GETCODE_ERROR_STATE_INVALID";

       #         $@ = "Error: workflow state must be PEND_ACT_CODE to get code";
       #         diag( $@, Dumper($msg) );
       #         return;
    }

    #	$msg = wfexec( $id, 'scpu_generate_activation_code', { _user => $u },0 );

    $msg = $client->send_receive_command_msg(
        'execute_workflow_activity',
        {
            'ID'       => $id,
            'ACTIVITY' => $act,
            'PARAMS'   => $params,
            'WORKFLOW' => $wf_type,
        },
    );
    
  

    if ( $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push(
            @{$errors},
		"I18N_OPENXPKI_CLIENT_GETAUTHCODE_ERROR_EXECUTING_SCPU_GENERATE_ACTIVATION_CODE"
        );
        #push( @{$errors}, $msg );
        

        # return undef;
    }
        
    if ( my $exc = OpenXPKI::Exception->caught() ) {
        if ( $exc->message() eq
	'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GENACTCODE_USER_NOT_AUTH_PERS '
          )
        {
            $responseData->{'error'} = "error";
            push(
                @{$errors},
"I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GENACTCODE_USER_NOT_AUTH_PERS"
            );

            #		return undef;

        }
        else {
            $responseData->{'error'} = "error";
            push(
                @{$errors},
"I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_GENACTCODE_USER_NOT_AUTH_PERS"
            );

            #		return undef;
        }
    }
    


  #
  #     $msg = wfexec( $id, 'scpu_generate_activation_code', {}, );
  #     if ( $self->is_error_response($msg) ) {
  #         $@ = "Error running scpu_generate_activation_code: " . Dumper($msg);
  #         return;
  # }
    #$session->{'errors'}        = $errors;

    #$session->{'responseData'}  = $responseData;
	$responseData->{'errors'} = $errors;
    sleep 1 if $sleep;



    $ret = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_password};
	
	
    $self->disconnect($client);

    if ( defined  $responseData->{'error'} && $responseData->{'error'} eq 'error' ) {
		  $responseData->{'msg'} = $ret;
        return $responseData;
    }

    #	eval {
    #	    $msg = $client->send_receive_service_msg('LOGOUT');
    #	};
    $responseData->{'msg'} = $ret;
    return $responseData;
}

1;

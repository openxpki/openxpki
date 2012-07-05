## OpenXPKI::Client::HTML::SC
##
## Written by Arkadius Litwinczuk 2010
## Copyright (C) 2010 by The OpenXPKI Project
## Base Class for subordinate perl modules
package OpenXPKI::Client::HTML::SC;

#common sense ;)
use strict;
use warnings;

#use utf8;
use English;

use JSON;
use OpenXPKI::Client;
use Config::Std;
use OpenXPKI::i18n qw( i18nGettext );
use Data::Dumper;
use Log::Log4perl qw(:easy);
use Crypt::CBC ;
use MIME::Base64;
use OpenXPKI::Client::HTML::SC::Dispatcher qw( config );

use base qw(
  Apache2::Controller
  Apache2::Request
);

use Apache2::Const -compile => qw( :http );

#Only these functions can be called via HTTP/Perlmod
sub allowed_methods {
    qw( get_auth_code puk_upload);
}    #only these fucntions can be called via handler

#Function to start_session
#Description: Start or resume OpenXPKI Session filter required parameter
#Required Parameter via HTTPRequest:
#		cardID  						- cardSerialNumber
#		cardType 					- CardType String
sub start_session {
    my ($self)        = @_;
    my $sessionID     = $self->pnotes->{a2c}{session_id};
    my $session       = $self->pnotes->{a2c}{session};
    my $responseData  = {};
    my $c             = 0;
    my $errors        = [];
    my $workflowtrace = [];
    my $ssousername   = undef;
    
    

#################################PARAMETER#################################

    if ( defined $self->{r}->headers_in()->get('ct-remote-user')
        && $self->{r}->headers_in()->get('ct-remote-user') ne '' )
    {
        $ssousername = $self->{r}->headers_in()->get('ct-remote-user');
        $session->{'creator_userID'} = $ssousername;
    }
    
    
    
    if(Log::Log4perl->initialized()) {

    } else {
   		 Log::Log4perl->init_once("/var/applications/apache/pki/conf/log.conf");
    }
   	my $log = Log::Log4perl->get_logger("openxpki.smartcard");

	$log->info("httpsessionid: ". $self->pnotes->{a2c}{session_id});


    if ( !defined $self->param("cardID") ) {
        $responseData->{'error'} = "error";
        push(
            @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_MISSING_CARDID"
        );
    }
    else {
        if ( defined $session->{'cardID'} ) {
            if ( $session->{'cardID'} ne $self->param("cardID") ) {

				#maybe rather silent restart of the session and no Error msg for the user

                $responseData->{'error'} = "error";
                my $r = push(
                    @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CARDID_NOTACCEPTED"
                );
                
                $c = $self->openXPKIConnection(
                    $session->{'openXPKI_Session_ID'},
                    $session->{'cardOwner'},
                    config()->{openxpki}->{role}
                );
                $self->disconnect($c);
		 $c = 0;
               
                

                $session->{'openxPKI_Session_ID'} = undef;
                $session->{'creator_userID'}	  = undef;
				$session->{'cardOwner'}		  = undef;
				$session->{'unblock_wfID'} 	  = undef;
				$session->{'perso_wfID'} 	  = undef;
				$session->{'perso_wfID'} 	  = undef;
				$session->{'ECDHPeerPubkey'} =  undef ;
				$session->{'rndPIN'} = undef ;
	 			$session->{'ECDHPubkey'} =  undef ;
	 			$session->{'PEMECKey'} = undef;
	 			$session->{'ECDHkey'} = undef;
	 			$session->{"install_puk_try"} = undef;
                $session->{'cardID'}              = $self->param("cardID");
                $responseData->{'cardID'}         = $session->{'cardID'};
                $responseData->{'userlogin'}      = $ssousername;
                $responseData->{'errors'}         = $errors;
                $responseData->{'workflowtrace'}  = $workflowtrace;
            }
        }
        else {
            $session->{'cardID'}      = $self->param("cardID");
            $responseData->{'cardID'} = $session->{'cardID'};
        }
    }

    if ( !defined $self->param("cardtype") ) {
        $responseData->{'error'} = "error";
        push(
            @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_MISSING_PARAMETER_CARDTYPE"
        );
    }
    else {
        $session->{'cardtype'} = $self->param('cardtype');
        my $card_id_prefix =
          config()->{'cardtypeids'}->{ $session->{'cardtype'} };

        if ( defined $card_id_prefix ) {
            $session->{'id_cardID'} = $card_id_prefix . $session->{'cardID'};
            $responseData->{'id_cardID'} = $session->{'id_cardID'};
        }
        else {
            $responseData->{'error'} = "error";
            my $r = push(
                @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CARDTYPE_INVALID"
            );
        }
    }

#########################OpenXPKI Session#############################

     if ( defined $session->{'openxPKI_Session_ID'} && defined $session->{'cardOwner'}){

                $c = $self->openXPKIConnection(
                    $session->{'openXPKI_Session_ID'},
                    $session->{'cardOwner'},
                    config()->{openxpki}->{role}
                );

         if ( !defined $c ) {
 
             # die "Could not instantiate OpenXPKI client. Stopped";
             $responseData->{'error'} = "error";
             push(
                 @{$errors},
	  "I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_ERROR_RESUME_SESSION_NO_CARDOWNER"
             );
            $c = 0;

        }else { 

	     if ( $c ne 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR_INIT_CONNECTION_FAILED'){

	      if ( $c != 0 ) {
		  $session->{'openxPKI_Session_ID'} = $c->get_session_id();
		  $responseData->{'start_msg'} = "OpenXPKISession resumed";
	      }
	    }

      }
  }



    $responseData->{'errors'}        = $errors;
    $responseData->{'workflowtrace'} = $workflowtrace;
    $session->{"responseData"}       = $responseData;
    $session->{"c"}                  = $c;

    ####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} && $responseData->{'error'} eq 'error' ) {
        return $self->send_json_respond($responseData)
          ;    #FIX-ME only deaktivated for testing
    }

}

#Function to openXPKIConnection
#Description: Start or resume OpenXPKI socket connection
# usage: my $msg = openXPKIConnection ( SessionID , $user , $pass );
#Parameter:
#		$openXPKISessionID  		- sessionID of an already open OpenXPKI socket
#		$u					- User
#		$p					- Password
sub openXPKIConnection {

    my ( $self, $openXPKISessionID, $u, $p ) = @_;
    my $socketfile = config()->{openxpki}->{socketfile};
    my $msg        = 0;
    my $c          = 0;

    eval {
        $c = OpenXPKI::Client->new(
            {
                SOCKETFILE => $socketfile,
                TIMEOUT    => 120
            }
        );
    };

    if ( my $exc = OpenXPKI::Exception->caught() ) {
        if ( $exc->message() eq 'I18N_OPENXPKI_CLIENT_INIT_CONNECTION_FAILED' )
        {

            # if we can not connect to the server, tell the user so
            my $re = i18nGettext(
'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR_INIT_CONNECTION_FAILED'
            );
            return $re;
        }
        else {
            my $re = i18nGettext(
                'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR')
              . $exc->message();
            return $re;
        }
    }
    elsif ($EVAL_ERROR) {
        return i18nGettext(
            'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_EVAL_ERROR');
    }

    if ( defined $openXPKISessionID ) {
        $msg = $c->init_session( { SESSION_ID => $openXPKISessionID } );
        if ( my $exc = OpenXPKI::Exception->caught() ) {
            if ( $exc->message() eq
'I18N_OPENXPKI_SERVICE_DEFAULT_HANDLE_CONTINUE_SESSION_SESSION_CONTINUE_FAILED'
              )
            {

                # if we can not connect to the server, tell the user so
                my $re = i18nGettext(
'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR_CONTINUE_SESSION_FAILED'
                );
            }
            $msg = 0;    #set msg null if connection failed
        }
    }

    if ( $msg == 0 ) {

        $msg = $c->init_session();

        if ( my $exc = OpenXPKI::Exception->caught() ) {
            return i18nGettext(
'I18N_OPENXPKI_CLIENT_WEBAPI_UTILITIES_OPENXPKICONNECTION_ERROR_STARTING_SESSION_FAILED'
              )
              . $msg
              . $exc->message();
        }
        $msg =
          $c->send_receive_service_msg( 'GET_PKI_REALM',
            { PKI_REALM => config()->{openxpki}->{pkiRealm} } );
        if ( $self->is_error_response($msg) ) {
            return i18nGettext(
'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR_GET_PKI_REALM'
            );
        }
#####################################ONLY TESTING#######################################
        # 		$msg = $c->send_receive_service_msg( 'PING',);
        # 		if ( $self->is_error_response($msg) ) {
        # #croak "response from PING: ", Dumper($msg);
        # #	$self->print("Ping Error:\n" . $msg );
        # 		return "Ping Error:\n" . $msg.Dumper($msg) ;
        # }
#####################################ONLY TESTING#######################################
        $msg =
          $c->send_receive_service_msg( 'GET_AUTHENTICATION_STACK',
            { 'AUTHENTICATION_STACK' => 'User', },
          );
        if ( $self->is_error_response($msg) ) {
            return i18nGettext(
'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR_GET_AUTH_STACK'
            );
        }

        $msg = $c->send_receive_service_msg(
            'GET_CLIENT_SSO_LOGIN',
            {
                'LOGIN'       => $u,
                'PSEUDO_ROLE' => '',
            },
        );
        if ( $self->is_error_response($msg) ) {
            return i18nGettext(
                'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR_LOGIN'
            );
        }
    }

    return $c;
}

#Function to send_json_respond
#Description: Encode json respnse and send to client
# usage: send_json_respond( $HTTPRESPONSEOBJECT , { 'Name' => 'valu' , 'Name2' => 'value' } )
#Parameter:
#		$HTTPRESPONSEOBJECT  		-(base class)
#		$data								-Perl Object , hash or array ref
sub send_json_respond {
    my ( $self, $data ) = @_;
    my $session = $self->pnotes->{a2c}{session};

    $data->{'id_cardID'} = $session->{'id_cardID'};
    $data->{'cardtype'}  = $session->{'cardtype'};
    $data->{'cardID'}    = $session->{'cardID'};

    my $utf8_encoded_json_text = encode_json($data);

    #$self->content_type('application/json');
    #	$self->content_type('text/json');
    $self->print($utf8_encoded_json_text);

    return Apache2::Const::HTTP_OK;
}

#Function to wfstate
#Description: get workflow state
# usage:  my $state = wfstate( $client, ID )
#Parameter:
#		$client 			-OpenXPKI Socket connection
#		$id				-Workflow ID
#		$wf_type			-Workflow Type
# Note: $@ contains either error message or Workflow state
sub wfstate {
    my ( $self, $client, $id, $wf_type ) = @_;
    my ( $msg, $state );

    if ( !defined $id ) {
        return "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATE_ERROR_WF_ID_REQUIRED";
    }
    if ( !defined $wf_type ) {
        $wf_type = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK';
    }

    $msg =
      $client->send_receive_command_msg( 'get_workflow_info',
        { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
    if ( $self->is_error_response($msg) ) {
        return
          "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATE_ERROR_CANT_GET_WORKFLOW_INFO";
    }
    return $msg->{PARAMS}->{WORKFLOW}->{STATE};
}

#Function to wfstate
#Description: get workflow state
# usage:  my $state = wfstate( $client, ID )
#Parameter:
#		$client 			-OpenXPKI Socket connection
#		$id				-Workflow ID
#		$wf_type			-Workflow Type
# Note: $@ contains either error message or Workflow information
sub wf_status {
    my ( $self, $client, $id, $wf_type ) = @_;
    my ( $msg, $state );

    if ( !defined $id ) {
        return "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATUS_ERROR_WF_ID_REQUIRED";
    }
    if ( !defined $wf_type ) {
        $wf_type = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK';
    }

    $msg =
      $client->send_receive_command_msg( 'get_workflow_info',
        { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
    if ( $self->is_error_response($msg) ) {
        return
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATUS_ERROR_CANT_GET_WORKFLOW_INFO";
    }
    return $msg;
}

#Function to is_error_response
#Description:  check an OpenXPKI Api call response for execution errors
# usage:  is_error_response( $msg )
#Parameter:
#		$msg 			-OpenXPKI API response msg
# usage: is_error_response($msg);
# Note: check an OpenXPKI Api call response for execution errors
sub is_error_response {
    my ( $self, $msg ) = @_;
    if ( defined $msg && $msg ne '' ) {
			
	
        if ( exists $msg->{'SERVICE_MSG'} && $msg->{'SERVICE_MSG'} eq 'ERROR' )
        {
            return 1;
        }
        else {
            return 0;
        }
    }
    else {
        return 0;
    }
}

#Function to wfdisconnect
#Description:  close OpenXPKI connection
# usage:  wfdisconnect( $client )
#Parameter:
#		$client 			-OpenXPKI Socket connection
# usage: wfdisconnect($client);
#
sub disconnect {
    my ( $self, $client ) = @_;
    eval { $client && $client->send_receive_service_msg('LOGOUT'); };
    $client = undef;
}

#Function to wfdisconnect
#Description:  close OpenXPKI connection
# usage:  wfdisconnect( $client )
#Parameter:
#		$client 			-OpenXPKI Socket connection
# usage: wfdisconnect($client);
#
sub session_encrypt {
	my ($self)    = shift;
	my $session = $self->pnotes->{a2c}{session};
	my $data = shift;
	
my $cipher;
my $iv;	
my $b64enc;	  

    if(Log::Log4perl->initialized()) {
		;
    } else {
   		 Log::Log4perl->init_once("/var/applications/apache/pki/conf/log.conf");
    }
   	my $log = Log::Log4perl->get_logger("openxpki.smartcard");

		#$log->debug('AES_KEY'.length($session->{'aeskey'}). ':' . $session->{'aeskey'} );
		eval{
		$cipher = Crypt::CBC->new( -key    =>  pack('H*', $session->{'aeskey'}),
                             -cipher => 'Crypt::OpenSSL::AES' );
		};
#		eval{
#		  $iv     = Crypt::CBC->random_bytes(16);
#		  $cipher = Crypt::CBC->new(-literal_key => 1,
#                           -key         =>  pack('H*', $session->{'aeskey'}),
#                           -iv          => $iv,
#                           -header      => 'none',
#                           -cipher => 'Crypt::OpenSSL::AES',
#                           -keysize     => 32 );
#		};
#		
		if($@ ne ''){
				$log->debug('Eval Error:'.$@);
		}
	
  		
	my $enc;
		#$log->debug('Clear :'.$data);
		eval{
			$enc = $cipher->encrypt($data);
		};
		
		#$log->debug('EncIV :'. $cipher->get_initialization_vector());
		#$log->debug('EncIV  B64=' . encode_base64($cipher->get_initialization_vector()));
		
		#$log->debug('Enc :'.$enc);
		#my $de = $cipher->decrypt($enc);
		#$log->debug('\nde:'.$de );
#		eval{
#			$log->debug('DeIV :'. $cipher->get_initialization_vector());
#			$log->debug('DeIV B64=' . encode_base64($cipher->get_initialization_vector()));
#		};

		
		$b64enc = encode_base64($enc);
 		#$log->debug('Eval Error:'.$@);
        #$log->debug('exec:'.$b64enc );
       
       	return $b64enc ;
	
}

1;
__END__

=head1 NAME

OpenXPKI::Client::HTML::SC - OpenXPKI Smartcard web services layer




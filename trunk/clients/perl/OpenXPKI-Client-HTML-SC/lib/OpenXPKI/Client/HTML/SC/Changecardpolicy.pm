## OpenXPKI::Client::HTML::SC::Changecardpolicy
##
## Written by Arkadius C. Litwinczuk 2012
## Copyright (C) 2012 by The OpenXPKI Project
package OpenXPKI::Client::HTML::SC::Changecardpolicy;

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
use OpenXPKI::Client::HTML::SC::Dispatcher qw( config );
use OpenXPKI::Serialization::Simple;



use base qw(
    Apache2::Controller
    Apache2::Request
    OpenXPKI::Client::HTML::SC
);

use Apache2::Const -compile => qw( :http );


#Only these functions can be called via HTTP/Perlmod
sub allowed_methods {
    qw( get_card_policy confirm_policy_change )
}    #only these fucntions can be called via handler

#Function get_card_policy
#Description: Create changecardpolicy workflow, and return a encrypted plugin command 
#Required Parameter via HTTPRequest:
#		cardID  				- cardSerialNumber
#		cardType 			- CardType String

sub get_card_policy {
    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $type         ;
    my $wf_type      = config()->{openxpki}->{changecardpolicy};
    my $sleep;
    my $errors;
    my $workflowtrace;
    my $msg;
    my $wf_ID; 
    my $PUK ='';
    my $disable = '';
    my $plugincommand = '';
    my $serializer = OpenXPKI::Serialization::Simple->new(); 
    

#################################PARAMETER#################################
    $self->start_session();   #call class helper function to create or reinitialise an OpenXPKI connection, and check for the required parameter cardID and cardtype

    $c            = $session->{"c"};
    $responseData = $session->{"responseData"};
    $errors	= $session->{"errors"};
    
    $workflowtrace 	=$session->{"workflowtrace"};
    
 #################################LOG4PERL###################################
    if ( Log::Log4perl->initialized() ) {

		# Yes, Log::Log4perl has already been initialized
		$responseData->{'log4perl init'} = "YES";
	}
	else {
		Log::Log4perl->init_once("/var/applications/apache/pki/conf/log.conf");

		# No, not initialized yet ...
		$responseData->{'log4perl init'} = "NO";
	}
	my $log = Log::Log4perl->get_logger("openxpki.smartcard");
	my $audit = Log::Log4perl->get_logger("openxpki.audit");
##############################################################################
	

#####################################check OpenXPKI connection######################################
	if ( !defined $c || $c == 0 ) {
		$responseData->{'error'} = "error";
		push(
			@{$errors},
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER"
		);

		$log->error( $session->{'id_cardID'}
			  . "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER"
		);

		$responseData->{'errors'} = $errors;
		return $self->send_json_respond($responseData);

	}

    my $ping_msg = $c->send_receive_service_msg('PING');
    if ($ping_msg->{SERVICE_MSG} eq 'SERVICE_READY') {
		$log->debug( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSO_OPENXPKI_RECONNECT_SUCCESS");
    }
    ## check the message
    if (! defined $ping_msg &&
        $c->get_communication_state ne "can_receive" &&
        ! $c->is_connected()
    ) {
    	
    	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKI_CONNECT_RESET");
    	$c = $self->openXPKIConnection(
	                undef,
	                $session->{'cardOwner'},
	                config()->{openxpki}->{role}
	         );
     
	     if ( !defined $c ) {
	            $responseData->{'error'} = "error";
	            push(
	                @{$errors},
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI_SESSION_START_FAILED"
	            );
	            $c = 0;
	            $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI_SESSION_START_FAILED"); 
	        }else{
	
	            if ( $c != 0 ) {
	            	$session->{'openxPKI_Session_ID'} = $c->get_session_id();
	            	$session->{"c"}            = $c;
	                $responseData->{'start_new_user_session'} = "OpenXPKISession started new User session";
	                 $log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSO_OPENXPKI_RESTART_SESSION");
	            }
	        }
    }
      
      if(!defined $session->{'aeskey'} || $session->{'aeskey'} eq '' ){
      	
      	                $responseData->{'error'} = "error";
                            push(
                 @{$errors},
		"I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_ERROR_NO_SESSION_KEY"
		  );

		$audit->fatal("I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_ERROR_NO_SESSION_KEY");


        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);
      	
      }
      
         if (defined $self->param("disable") ) {
        	 if($self->param("disable") eq 'true' )
        	 {
        	 	 $disable = 'true'; 
		    	push(
							@{$workflowtrace},
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_DISABLE_TRUE"
						);
			$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_DISABLE_TRUE");
        	 	
        	 }				
   		 }
      

 $audit->fatal("I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_ERROR_NO_SESSION_KEY");
####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);
    }
#############################################################################



        $msg = $c->send_receive_command_msg(
            'create_workflow_instance',
            {   'PARAMS'   => { token_id => $session->{'id_cardID'}, },
                'WORKFLOW' => $wf_type,
            },
        );
		
        if ( $self->is_error_response($msg) ) {
            $responseData->{'error'} = "error";
            push( @{$errors},
                "I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CREATE_WORKFLOW_INSTANCE"
            );
        }else{
        	 $wf_ID = $msg->{PARAMS}->{WORKFLOW}->{ID};
        	 
				push( @{$workflowtrace},
						"I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_SUCCESS_CREATE_WORKFLOW_INSTANCE"
				);

				$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_SUCCESS_CREATE_WORKFLOW_INSTANCE");
				
				
			 my $got_puk = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk};
			 
        #$session->{'puk'}      = $got_puk;
	
			if(defined $got_puk && $got_puk ne '')
			{
				
	
				$PUK     = $serializer->deserialize( $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk} );
	
	
				if(defined  $PUK &&  $PUK ne '')
				{
					if($disable ne '')
					{
						$plugincommand =
						   'SetPINPolicy;CardSerial='
						  . $session->{'cardID'} 
						  . ';PUK='.$PUK->[0].';B64Data='. config()->{card}->{b64cardPolicyOff}.";";
						
					}else{
						$plugincommand =
						   'SetPINPolicy;CardSerial='
						  . $session->{'cardID'} 
						  . ';PUK='.$PUK->[0].';B64Data='. config()->{card}->{b64cardPolicyOn}.";";
						
					}							
				}
			}
        }

    if ( $wf_ID eq 'undefined' ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CREATING_WORKFLOW"
        );
        $log->error('I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CREATING_WORKFLOW');
    }

		$log->info("WFState:".$msg->{PARAMS}->{WORKFLOW}->{STATE});
#        if ((  $msg->{PARAMS}->{WORKFLOW}->{STATE} ) eq 
#                'HAVE_TOKEN_OWNER')

    	$log->info(
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_ENCRYPT_OUT_DATA"
		);

	if ( $plugincommand ne '' ) {
		
		eval{
		$responseData->{'exec'} = $self->session_encrypt($plugincommand) ;
		};
		#$log->info('action:'.$responseData->{'action'});
        $log->info('exec:'.$@.$responseData->{'exec'});
	}


   # $session->{'changecardpolicy_state'} =$msg->{PARAMS}->{WORKFLOW}->{STATE} ;
    $wf_ID =$msg->{PARAMS}->{WORKFLOW}->{ID};
    $responseData->{'changecardpolicy_wfID'}=$wf_ID;
    $responseData->{'cardID'} = $session->{'cardID'};
    $responseData->{'state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
	 $responseData->{'workflowtrace'} = $workflowtrace;

	#$responseData->{'openxPKI_Session_ID'} = $c->get_session_id();   #for testing only FIXME

    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
    }

    return $self->send_json_respond($responseData);

}

#Function confirm_policy_change
#Description: Create changecardpolicy workflow, and return a encrypted plugin command 
#Required Parameter via HTTPRequest:
#		cardID  				- cardSerialNumber
#		cardType 			- CardType String
#       Result 				- Plugin Result
#Optinal Parameter via HTTPRequest:
#		Reason 				- Error reason

sub confirm_policy_change {
    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $type         ;
    my $wf_type      = config()->{openxpki}->{changecardpolicy};
    my $sleep;
    my $errors;
    my $action;
    my $result;
    my $workflowtrace;
    my $msg;
    my $wf_ID; 
    my $plugincommand = '';
    my $serializer = OpenXPKI::Serialization::Simple->new(); 
    my $changecardpolicy_Reason ; 
    

#################################PARAMETER#################################
    $self->start_session();   #call class helper function to create or reinitialise an OpenXPKI connection, and check for the required parameter cardID and cardtype

    $c            = $session->{"c"};
    $responseData = $session->{"responseData"};
    $errors	= $session->{"errors"};
    
    $workflowtrace 	=$session->{"workflowtrace"};
    
 #################################LOG4PERL###################################
    if ( Log::Log4perl->initialized() ) {

		# Yes, Log::Log4perl has already been initialized
		$responseData->{'log4perl init'} = "YES";
	}
	else {
		Log::Log4perl->init_once("/var/applications/apache/pki/conf/log.conf");

		# No, not initialized yet ...
		$responseData->{'log4perl init'} = "NO";
	}
	my $log = Log::Log4perl->get_logger("openxpki.smartcard");
	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_CALL");
	my $audit = Log::Log4perl->get_logger("openxpki.audit");
##############################################################################
	

      if (!defined $c || $c == 0)
      {
                $responseData->{'error'} = "error";
                            push(
                 @{$errors},
		"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER"
		  );

		$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER");


        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);

      }
      
       if ( defined $self->param("changecardpolicy_wfID") ) {
        $wf_ID     = $self->param("changecardpolicy_wfID");
        $responseData->{'changecardpolicy_wfID'} = $wf_ID ;

    	}else{
    		$responseData->{'error'} = "error";
                            push(
                 @{$errors},
		"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_NO_CHANGECARDPOLICY_WFID"
		  );

		$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_NO_CHANGECARDPOLICY_WFID");
    		
    	}
    	
    	if ( defined $self->param("Result") ) {
        $result      = $self->param("Result");
        $responseData->{'changecardpolicy_Result'} = $result;

    	}else{
    		$responseData->{'error'} = "error";
                            push(
                 @{$errors},
		"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_NO_CHANGECARDPOLICY_RESULT"
		  );

		$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_NO_CHANGECARDPOLICY_RESULT");
    		
    	}
    	
    	if ( defined $self->param("Reason") ) {
	        $changecardpolicy_Reason      = $self->param("Reason");
	        $responseData->{'changecardpolicy_Reason'} = $changecardpolicy_Reason;

    	}
    	
      
      if(!defined $session->{'aeskey'} || $session->{'aeskey'} eq '' ){
      	
      	                $responseData->{'error'} = "error";
                            push(
                 @{$errors},
		"I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_ERROR_NO_SESSION_KEY"
		  );

		$audit->fatal("I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_ERROR_NO_SESSION_KEY");


        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);
      	
      }

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
    	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_ERROR_RESPONSE");
        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);
    }
#############################################################################

    if ( $result eq "SUCCESS" ) {
        $action = 'scfp_ack_fetch_puk';
	       
	    $msg = $c->send_receive_command_msg(
	        'execute_workflow_activity',
	        {   'ID'       => $wf_ID,
	            'ACTIVITY' => $action,
	            'PARAMS'   => {},
	            'WORKFLOW' => $wf_type ,
	        },
	    );
        
    }
    else {
        $action = 'scfp_puk_fetch_err';
        
	        
	    $msg = $c->send_receive_command_msg(
	        'execute_workflow_activity',
	        {   'ID'       => $wf_ID,
	            'ACTIVITY' => $action,
	            'PARAMS'   => { error_reason => $changecardpolicy_Reason },
	            'WORKFLOW' => $wf_type ,
	        },
	    );
    }
    $log->info("action $action");
		
        if ( $self->is_error_response($msg) ) {
            $responseData->{'error'} = "error";
            push( @{$errors},
                "I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CONFIRM_CHANGE_RESULT"
            );
        }else{
        	 $wf_ID = $msg->{PARAMS}->{WORKFLOW}->{ID};
        	 
				push( @{$workflowtrace},
						"I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_SUCCESS_CONFIRM_CHANGE_RESULT"
				);

				$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_SUCCESS_CONFIRM_CHANGE_RESULT");	
        }

    if ( $wf_ID eq 'undefined' ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CONFIRM_CHANGE_RESULT"
        );
        $log->error('I18N_OPENXPKI_CLIENT_WEBAPI_CHANGECARDPOLICY_ERROR_CONFIRM_CHANGE_RESULT');
    }

		$log->info("WFState:".$msg->{PARAMS}->{WORKFLOW}->{STATE});

   # $session->{'changecardpolicy_state'} =$msg->{PARAMS}->{WORKFLOW}->{STATE} ;
    $responseData->{'changecardpolicy_wfID'}= $msg->{PARAMS}->{WORKFLOW}->{ID}; 
    $responseData->{'cardID'} = $session->{'cardID'};
    $responseData->{'state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
	 $responseData->{'workflowtrace'} = $workflowtrace;

	#$responseData->{'openxPKI_Session_ID'} = $c->get_session_id();   #for testing only FIXME

    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
    }
	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_CHANGECARDPOLICY_RESPONSE");
    return $self->send_json_respond($responseData);

}




1;

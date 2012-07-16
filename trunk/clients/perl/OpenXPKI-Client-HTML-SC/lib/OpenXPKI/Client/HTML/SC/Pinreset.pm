## OpenXPKI::Client::HTML::SC::Pinreset
##
## Written by Arkadius C. Litwinczuk 2010
## Copyright (C) 2010 by The OpenXPKI Project
package OpenXPKI::Client::HTML::SC::Pinreset;

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
#use Data::Dumper;
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
    qw( get_auth_code start_pinreset pinreset_verify pinreset_confirm pinreset_cancel)
}    #only these fucntions can be called via handler

#Function start_pinreset
#Description: Create pinreset workflow, and choose authorising persons
#Required Parameter via HTTPRequest:
#		cardID  				- cardSerialNumber
#		cardType 			- CardType String
#		email1 				- authorising person1
#		email2 				- authorising person2
#Optional Parameter via HTTPRequest:
#		unblock_wfID		- WorkflowID
sub start_pinreset {
    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $type         ;
    my $wf_type      = config()->{openxpki}->{pinunblock};
    my $sleep;
    my $errors;
    my $workflowtrace;
    my $msg;
    my $wf_ID; 

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
	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_STARTRESET_CALL");
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

    if ( !defined $self->param("email1") ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_MISSING_PARAMETER_EMAIL1"
        );
    }
    else {
        $session->{'email1'}      = $self->param('email1');
        $responseData->{'email1'} = $session->{'email1'};
		$log->debug($session->{'email1'});
    }

    if ( !defined $self->param("email2") ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_MISSING_PARAMETER_EMAIL2"
        );
    }
    else {
        $session->{'email2'}      = $self->param('email2');
        $responseData->{'email2'} = $session->{'email2'};
        $log->debug($session->{'email2'});
    }

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);
    }
#############################################################################

    if ( defined $self->param('unblock_wfID') && $self->param('unblock_wfID') ne '') {
			if($self->param('unblock_wfID') =~ /^[0-9]+$/){
				$wf_ID      = $self->param('unblock_wfID');
				$responseData->{'unblock_wfID'} = $wf_ID;
				$responseData->{'configwftype'} = $wf_type;	
				$log->debug('posted UnblockWF ID:'.$wf_ID );
			}
		 
		my $oldState = $self->wfstate( $c, $wf_ID , $wf_type);
		$log->debug('posted UnblockWF state:'.$oldState );
 		

		if(defined $oldState &&  $oldState ne "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATE_ERROR_CANT_GET_WORKFLOW_INFO" && $oldState ne "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATE_ERROR_WF_ID_REQUIRED" )
		{
			if ( ( $oldState eq 'SUCCESS' )
					or ( $oldState eq 'FAILURE' )
					or ( $oldState  eq
						'I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATE_ERROR_CANT_GET_WORKFLOW_INFO')
					)
			{
					$wf_ID = 'undefined';
	
	# 			$responseData->{'error'} = "error";
	# 			push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_WF_ID_INVALID");
			}
		}else
		{
			$wf_ID = 'undefined';
		}
    }

    $log->info('Unblock wfID:'.$wf_ID);


    if (   ( !defined $wf_ID  )
        or ( $wf_ID eq 'undefined' ) )
    {

        $msg = $c->send_receive_command_msg(
            'create_workflow_instance',
            {   'PARAMS'   => { token_id => $session->{'id_cardID'}, },
                'WORKFLOW' => $wf_type,
            },
        );
		#$log->debug(Dumper( $msg));
        if ( $self->is_error_response($msg) ) {
            $responseData->{'error'} = "error";
            push( @{$errors},
                "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_CREATE_WORKFLOW_INSTANCE"
            );
        }
        else {
				push( @{$workflowtrace},
						"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_SUCCESS_CREATE_WORKFLOW_INSTANCE"
				);

				$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_SUCCESS_CREATE_WORKFLOW_INSTANCE");

        }

        if ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'HAVE_TOKEN_OWNER' ) {
				push( @{$workflowtrace},
						"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_STATE_HAVE_TOKEN_OWNER"
				);


				$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_STATE_HAVE_TOKEN_OWNER");

        }
        else {
            $responseData->{'error'} = "error";
            push( @{$errors},
                "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STATE_HAVE_TOKEN_OWNER_REQUIRED"
            );
        }

        $wf_ID = $msg->{PARAMS}->{WORKFLOW}->{ID};
        $responseData->{'unblock_wfID'} = $wf_ID;
        if ( !defined $wf_ID or $wf_ID eq '' ) {
            $responseData->{'error'} = "error";
            push( @{$errors},
                "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_WF_ID_REQUIRED"
            );
        }

    }else{

        $msg = $c->send_receive_command_msg(
            'execute_workflow_activity',
            {   'ID'       => $wf_ID,
                'ACTIVITY' => 'scunblock_initialize',
            },
        );
        #$log->debug(Dumper($msg));
       

        if ( $self->is_error_response($msg) ) {
            $responseData->{'error'} = "error";
            #$responseData->{'msg'}   = Dumper($msg);
            push( @{$errors},
                "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_REINITIALIZE_WORKFLOW"
            );

# 		if($msg->{LIST}->[0]->{LABEL} eq "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SCPU_INVALID_AUTHID")
# 		{
# 			$responseData->{'popup_msg'} = "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_INVALID_USER ".$msg->{LIST}->[1]->{LABEL} ;
#
# 		}

        }
        else {
				push( @{$workflowtrace},
						"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_SUCCESS_INITIALIZE"
				);
#             $responseData->{'msg'}
#                 = $responseData->{'msg'}
#                 . "Successfully executed store_auth_ids'"
#                 . $session->{'cardID'};
        }

    }

    if ( $wf_ID eq 'undefined' ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_WF_ID_REQUIRED"
        );
    }
    else {
		$log->info("WFState:".$msg->{PARAMS}->{WORKFLOW}->{STATE});
        if ((  $msg->{PARAMS}->{WORKFLOW}->{STATE} ) eq 
                'HAVE_TOKEN_OWNER')
        {
            $msg = $c->send_receive_command_msg(
                'execute_workflow_activity',
                {   'ID'       => $wf_ID,
                    'ACTIVITY' => 'scunblock_store_auth_ids',
                    'PARAMS'   => {
                        auth1_id => $session->{'email1'},
                        auth2_id => $session->{'email2'}
                    },
                    'WORKFLOW' => $wf_type,
                },
            );
           #$log->debug(Dumper($msg));

            if ( $self->is_error_response($msg) ) {
                $responseData->{'error'} = "error";
                push( @{$errors},
                    "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STORE_AUTH_IDS"
                );
#   	 				push( @{$errors},
#                     Dumper($msg)
#                 );


            }
            else {

				push( @{$workflowtrace},
								"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_SUCCESS_STORE_AUTHIDS"
						);

                 $responseData->{'auth1_ldap_mail'} = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth1_ldap_mail};
					  $responseData->{'auth2_ldap_mail'} = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth2_ldap_mail};

				$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_SUCCESS_STORE_AUTHIDS");
				$log->info('AuthID1Stored:'.$msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth1_ldap_mail});
				$log->info('AuthID2Stored:'.$msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth2_ldap_mail});
            $responseData->{'auth1_ldap_mail'} = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth1_ldap_mail};
			$responseData->{'auth2_ldap_mail'} = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth2_ldap_mail};

#                     = $responseData->{'msg'}
#                     . "Successfully executed store_auth_ids'"
#                     . $session->{'cardID'};
            }
            
            my $actual_state = $self->wfstate( $c, $wf_ID, $wf_type  );

            if ( $actual_state eq 'PEND_ACT_CODE' ) {
				push( @{$workflowtrace},
								"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_STATE_PEND_ACT_CODE"
						);
#                 $responseData->{'msg'}
#                     = $responseData->{'msg'} . "Workflow store_auth_ids OK";
            }
            else {

                $responseData->{'error'} = "error";
                push( @{$errors},
                    "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STATE_PAND_ACT_CODE_REQUIRED"
                );

#$responseData->{'error'} = $responseData->{'error'}."State after store_auth_ids must be PEND_ACT_CODE: ".Dumper($msg) ;
            }

            #$self->print("executed:".$msg->{PARAMS}->{WORKFLOW}->{STATE} );
# 
#             $responseData->{'state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#             $session->{'state'}      = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#             $responseData->{'msg'}   = $msg;

        }else{
			$responseData->{'error'} = "error";
			push( @{$errors},
					"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_START_PINRESET_ERROR_STATE_HAVE_TOKEN_OWNER_REQUIRED"
			);

}
    }
    $session->{'unblockWf_state'} =$msg->{PARAMS}->{WORKFLOW}->{STATE} ;
    $wf_ID =$msg->{PARAMS}->{WORKFLOW}->{ID};
    $responseData->{'unblock_wfID'}=$wf_ID;
    $responseData->{'cardID'} = $session->{'cardID'};
    $responseData->{'state'}  =  $session->{'unblockWf_state'};
	 $responseData->{'workflowtrace'} = $workflowtrace;

	#$responseData->{'openxPKI_Session_ID'} = $c->get_session_id();   #for testing only FIXME

    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
    }
$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_STARTRESET_RESPONSE");

    return $self->send_json_respond($responseData);

}

#Function list active workflows
#Description: Find active workflows for cardID
#Required Parameter via HTTPRequest:
#		cardID  						- cardSerialNumber
#		cardType 					- CardType String
sub list_active_workflows {
    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $type;
    my $wf_type = config()->{openxpki}->{pinunblock};   # $wf_pin_unblock ;
    my $u = config()->{openxpki}->{user};
    my $p = config()->{openxpki}->{role};
    my $msg;
    my $wf_ID;
    my $action;
	my $workflowtrace;
	my $errors	;
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
##############################################################################

    $self->start_session();
    $c            = $session->{"c"};
    $responseData = $session->{"responseData"};
 	 $errors				= $session->{"errors"};
 	 $workflowtrace 	=$session->{"workflowtrace"};

 	 $responseData->{"wf_type"} = $wf_type;

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

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        return $self->send_json_respond($responseData);
    }

    # At this point, the user has re-started the session and should get
    # the current workflow for the inserted token id

    $msg = $c->send_receive_command_msg(
        'search_workflow_instances',
        {   CONTEXT => [
                {   KEY   => 'token_id',
                    VALUE => $session->{'id_cardID'},
                },
            ],
            TYPE => $wf_type,
        },
    );

    if ( $self->is_error_response($msg) ) {
        $responseData->{'error'} = 'error';
			 push( @{$errors},
            "I18N_OPENXPKI_CLIENT_ERROR_SEARCH_WORKFLOW_INSTANCES");
            

    }
    else {
        $responseData->{'msg'}
            = $responseData->{'msg'}
            . "I18N_OPENXPKI_CLIENT_SUCCESS_SEARCH_WORKFLOW_INSTANCES"
            . $session->{'id_cardID'};
    }

# ok( !$self->is_error_response($msg), 'Successfully ran search_workflow_instances' )
#    or die( "Error running search_workflow_instances: ", Dumper($msg) );

    my @workflows
        = sort {
        $b->{'WORKFLOW.WORKFLOW_SERIAL'} <=> $a->{'WORKFLOW.WORKFLOW_SERIAL'}
        }
        grep {
        not(   ( $_->{'WORKFLOW.WORKFLOW_STATE'} eq 'SUCCESS' )
            or ( $_->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE' ) )
        } @{ $msg->{PARAMS} };

# assume that it's the first one!
# is( $workflows[0]->{'WORKFLOW.WORKFLOW_SERIAL'},
#    $wf_id, 'Workflow ID matches our ID' )
#    or die("Workflow ID returned for token_id does not match our workflow ID: ", $@, Dumper($msg) );
    $wf_ID = $workflows[0]->{'WORKFLOW.WORKFLOW_SERIAL'};
    my $count = @workflows;
    $responseData->{'count_wf_id'}   = $count;
    #$responseData->{'wf_array_item'} = Dumper( $workflows[0] );
    my $i;
    for ( $i = 0; $i < $count; $i++ ) {
        if ( defined $workflows[$i]->{'WORKFLOW.WORKFLOW_SERIAL'} ) {
            $responseData->{ 'wf' . $i }
                = $workflows[$i]->{'WORKFLOW.WORKFLOW_SERIAL'} 
                . "State="
                . $self->wfstate( $c,
                $workflows[$i]->{'WORKFLOW.WORKFLOW_SERIAL'}, $wf_type );
        }
    }

    return $self->send_json_respond($responseData);

}

#Function pinreset_verify
#Description:Verify auth codes and fetch PUK
#Required Parameter via HTTPRequest:
#		cardID  						- cardSerialNumber
#		cardType 					- CardType String
#		activationCode1 			- authorising person1
#		activationCode2 			- authorising person2
#Optional Parameter via HTTPRequest:
#		unblock_wfID						- WorkflowID
sub pinreset_verify {

    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $wf_type      = config()->{openxpki}->{pinunblock};
    my $u            = config()->{openxpki}->{user};
    my $p            = config()->{openxpki}->{role};
    my $wf_ID;
    my $errors;
	my $workflowtrace; 
	my $plugincommand;	
    my $msg;
    my $serializer = OpenXPKI::Serialization::Simple->new(); 

#########start session#######
    $self->start_session();
    $c            = $session->{"c"};
    $responseData = $session->{"responseData"};
    $errors				= $session->{"errors"};
 	$workflowtrace 	=$session->{"workflowtrace"};
    $responseData->{'error'} = undef;
    
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
	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PINRESETVERIFY_CALL");
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
    
#################################PARAMETER#################################
# 	if(! defined $self->param("email1") )
# 	{
# 		$responseData->{'error'} = "error";
# 		push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_EMAIL1");
# 	}else{
# 		$session->{'email1'} = $self->param('email1');
# 		$responseData->{'email1'} = $session->{'email1'};
# 	}
#
# 	if(! defined $self->param("email2") )
# 	{
# 		$responseData->{'error'} = "error";
#       push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_EMAIL2");
# 	}else{
# 		$session->{'email2'} = $self->param('email2');
# 		$responseData->{'email2'} = $session->{'email2'};
# 	}
#my $userpin;
    if ( !defined $self->param("activationCode1") ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_ACTIVATIONCODE1"
        );
        $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_ACTIVATIONCODE1");
    }
    else {
        $session->{'activationCode1'}      = $self->param('activationCode1');
        $responseData->{'activationCode1'} = $session->{'activationCode1'};
    }

    if ( !defined $self->param("activationCode2") ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_ACTIVATIONCODE2"
        );
       $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_ACTIVATIONCODE2");
        
    }
    else {
        $session->{'activationCode2'}      = $self->param('activationCode2');
        $responseData->{'activationCode2'} = $session->{'activationCode2'};
    }

#    if ( !defined $self->param("userpin") ) {
#        $responseData->{'error'} = "error";
#        push( @{$errors},
#            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_USERPIN"
#        );
#    }
#    else {
#        $userpin = $self->param('userpin');
#    }


    if ( !defined $self->param("unblock_wfID") || $self->param("unblock_wfID") eq '' ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_WF_ID"
        );
          $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_WF_ID");
    
    }else{
	    
        $wf_ID      = $self->param('unblock_wfID');
        $responseData->{'unblock_wfID'} = $wf_ID;
        $log->info("unblock_wfID: ".$wf_ID );
    }

    if ( !defined $wf_ID ) {

# At this point, the user has re-started the session and should get
# 	# the current workflow for the inserted token id
# 	$msg = $c->send_receive_command_msg(
# 		'search_workflow_instances',
# 	{   CONTEXT => [
# 	{
# 				KEY => 'token_id',
# 				VALUE => $session->{'id_cardID'},
# 	},
# 			],
# 			TYPE => $wf_type,
# 	},
# 	);
#
# 	if( $self->is_error_response($msg) )
# 	{
# 		$responseData->{'error'} = "error";
#       push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_SEARCH_WORKFLOW_INSTANCES".Dumper($msg));
#
# 	}else{
# 		$responseData->{'msg'} =  $responseData->{'msg'}."I18N_OPENXPKI_CLIENT_SUCCESS_SEARCH_WORKFLOW_INSTANCES". $session->{'id_cardID'} ;
# 	}
#
# 	# ok( !$self->is_error_response($msg), 'Successfully ran search_workflow_instances' )
# 	#    or die( "Error running search_workflow_instances: ", Dumper($msg) );
#
# 	my @workflows =
# 		sort { $b->{'WORKFLOW.WORKFLOW_SERIAL'} <=> $a->{'WORKFLOW.WORKFLOW_SERIAL'} }
# 		grep { not (
# 				( $_->{'WORKFLOW.WORKFLOW_STATE'} eq 'SUCCESS' ) or
# 				( $_->{'WORKFLOW.WORKFLOW_STATE'} eq 'FAILURE' ) ) }
# 		@{ $msg->{PARAMS} };
#
# 	# assume that it's the first one!
# 	# is( $workflows[0]->{'WORKFLOW.WORKFLOW_SERIAL'},
# 	#    $wf_id, 'Workflow ID matches our ID' )
# 	#    or die("Workflow ID returned for token_id does not match our workflow ID: ", $@, Dumper($msg) );
# 	$wf_id = $workflows[0]->{'WORKFLOW.WORKFLOW_SERIAL'};
# # 	my $count = @workflows ;
# # 	$responseData->{'count_wf_id'} = $count;
# #	$responseData->{'wf_array_item'} = Dumper($workflows[0]);
#
# 	if( defined $wf_id){
# 	$responseData->{'wf_ID'} =  $wf_id;
# 	$session->{'wf_ID'}  = $wf_id;
# 	}else
# 	{
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_WF_ID_REQUIRED"
        );
        $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_WF_ID_REQUIRED");

        # 	}

    }
    else {
        $responseData->{'unblock_wfID'} = $wf_ID;
    }

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);
    }
#############################################################################

    $responseData->{'unblock_wfID'} = $wf_ID;
    my $actual_state = $self->wfstate( $c, $wf_ID, $wf_type  );
	$log->info('UnblockWF State:'.$actual_state);
	if($actual_state eq 'FAILURE' ){
		$session->{'wfstate'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
	
		$responseData->{'workflowtrace'} = $workflowtrace;

		$responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_WF_FAILURE"
        );
        $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_WF_FAILURE");
        

	
		if ( defined $responseData->{'error'} ) {
			$responseData->{'errors'} = $errors;
		}

    	return $self->send_json_respond($responseData);

	}

#	if($actual_state eq 'CAN_WRITE_PIN' ){
#	#user already fatched puk and wants only to encrypt an other PIN 
#
#			$userpin .= "\00";
#			
#				my $encrypted = $c->send_receive_command_msg( 'deuba_aes_encrypt_parameter' ,{
#				DATA => $userpin,
#			});
#			
# 			#FIX ME maybe handle possible exception
#			$responseData->{'pin'}  = $encrypted->{PARAMS};
#			$responseData->{'puk'}  = undef;
#	
#		$session->{'wfstate'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#	
#		$responseData->{'workflowtrace'} = $workflowtrace;
#	
#		if ( defined $responseData->{'error'} ) {
#			$responseData->{'errors'} = $errors;
#		}
#
#    	return $self->send_json_respond($responseData);
#     }


    if (   ( $actual_state eq 'PEND_PIN_CHANGE' )
        or ( $actual_state eq 'PEND_ACT_CODE' ) )
	    {
	
	        $msg = $c->send_receive_command_msg(
	            'execute_workflow_activity',
	            {   'ID'       => $wf_ID,
	                'ACTIVITY' => 'scunblock_post_codes',
	                'PARAMS'   => {
	                    _auth1_code => $session->{'activationCode1'},
	                    _auth2_code => $session->{'activationCode2'},
	                },
	                'WORKFLOW' => $wf_type ,
	            },
	        );
	    # $log->debug(Dumper($msg));
	
		if ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'CAN_FETCH_PUK' )
		{
			push( @{$workflowtrace},
				"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_SUCCESS_VERIFY_AUTHCODES_STATE_CAN_FATCH_PUK");
			  $log->info('I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_SUCCESS_VERIFY_AUTHCODES_STATE_CAN_FATCH_PUK');
		}else{
			$responseData->{'error'} = "error";
			push( @{$errors},
				"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_AUTHCODES_INCORRECT");
			
		$log->error('I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_AUTHCODES_INCORRECT');
			
		}
       
	    }else {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_STATE_PEND_PIN_CHANGE_REQUIRED");
		$log->error('I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_STATE_PEND_PIN_CHANGE_REQUIRED');
    }

    # Provide correct codes and pins

	
    if ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'CAN_FETCH_PUK' ) {
#         $responseData->{'msg'}
#             = $responseData->{'msg'}
#             . "I18N_OPENXPKI_CLIENT_SUCCESS_VERIFY_CODES_CAN_FETCH_PUK"
#             . $session->{'cardID'};

        $msg = $c->send_receive_command_msg(
            'execute_workflow_activity',
            {   'ID'       => $wf_ID,
                'ACTIVITY' => 'scunblock_fetch_puk',
                'PARAMS'   => {},
                'WORKFLOW' =>  $wf_type ,
            },
        );
        
      #$log->debug(Dumper($msg));


        my $got_puk = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk};
        #$session->{'puk'}      = $got_puk;
	
		if(defined $got_puk && $got_puk ne '')
		{

			my $PUK     = $serializer->deserialize( $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk} );


			if(defined  $PUK &&  $PUK ne '')
			{
				
					$plugincommand =
					    'ResetPIN;CardSerial='
					  . $session->{'cardID'} 
					  . ';PUK='.$PUK->[0].';';
			 #$log->debug('Pinreset_plugincommand: '. $plugincommand);
	
			}
      #  $responseData->{'puk'} = $got_puk;

        if ( $self->is_error_response($msg) ) {
            $responseData->{'error'} = "error";
            push( @{$errors},
                "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_FETCH_PUK_FAILED");
		push(@{$errors},$msg);
        }
        else {
					push( @{$workflowtrace},
								"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_SUCCESS_FETCH_PUK");
							
#             $responseData->{'msg'}
#                 = $responseData->{'msg'}
#                 . "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_SUCCESS_FETCH_PUK"
#                 . $session->{'cardID'};
        }

    }
    }
    else {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_ERROR_VERIFY_CODES_STATE_CAN_FETCH_PUK_REQUIRED"
                 );
    }

#    if ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'CAN_WRITE_PIN' ) {
#			push( @{$workflowtrace},
#								"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_SUCCESS_CAN_WRITE_PIN");
#			
#			# append 0 byte
#			$userpin .= "\00";
#			
#				my $encrypted = $c->send_receive_command_msg( 'deuba_aes_encrypt_parameter' ,{
#				DATA => $userpin,
#			});
			
 			#FIX ME maybe handle possible exception
#			$responseData->{'pin'}  = $encrypted->{PARAMS};
 			
#         $responseData->{'msg'}
#             = $responseData->{'msg'}
#             . "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_SUCCESS_CAN_WRITE_PIN"
#             . $session->{'cardID'};
#    }
 #   else {
 #       $responseData->{'error'} = "error";
 #       push( @{$errors},
 #           "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_STATE_CAN_WRITE_PIN_REQUIRED"
 #                );
 #   }

    #is ( wfparam( $wf_id, '_puk' ), $act_test{user}->{puk},
    #       "check puk returned from datapool") or diag($@);

    # Wrap it up by changing state to success

    # $msg = wfexec( $wf_id, 'write_pin_ok', {} );
    # ok( !$self->is_error_response($msg), 'Successfully ran write_pin_ok' )
    #     or die( "Error write_pin_ok MSG: ", Dumper($msg) );
    #
    # is( wfstate($wf_id), 'SUCCESS', 'Workflow state after write_pin_ok' )
    #     or die("State after write_pin_ok must be SUCCESS:", $@);
    #
    		$log->info(
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_ENCRYPT_OUT_DATA"
		);
		#$log->info("Plugin command to enc:".$plugincommand);
	if ( $plugincommand ne '' ) {
		
		eval{
		$responseData->{'exec'} = $self->session_encrypt($plugincommand) ;
		};
		#$log->info('action:'.$responseData->{'action'});
        $log->info('exec:'.$@.$responseData->{'exec'});
	}
    
    $session->{'wfstate'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
    $responseData->{'wfstate'} = $session->{'wfstate'};
	$responseData->{'workflowtrace'} = $workflowtrace;

    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
    }
$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PINRESETVERIFY_RESPONSE");
    return $self->send_json_respond($responseData);

}

#Function pinreset_confirm
#Description: set final pinreset workflow state
#Required Parameter via HTTPRequest:
#		cardID  						- cardSerialNumber
#		cardType 					- CardType String
#		unblock_wfID				- Workflow ID
#		Result 						- Cardreader Operation Result
#Optional Parameter via HTTPRequest:
#		Reason 						- Cardreader Reason (if error)
sub pinreset_confirm {
    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $type;
    my $wf_type = config()->{openxpki}->{pinunblock};
    my $u       = config()->{openxpki}->{user};
    my $p       = config()->{openxpki}->{role};
    my $msg;
    my $errors;
	 my $workflowtrace;
    my $wf_ID;
    my $action;

#################################PARAMETER#################################
    $self->start_session();
    $c            = $session->{"c"};
    $responseData = $session->{"responseData"};
    $errors				= $session->{"errors"};
 	 $workflowtrace 	=$session->{"workflowtrace"};
	 $responseData->{'error'} = undef;
	 
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
	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PINRESETCONFIRM_CALL");
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

    if ( defined $self->param("unblock_wfID") ) {
        $session->{'wf_ID'}      = $self->param("unblock_wfID");
        $responseData->{'unblock_wfID'} = $session->{'wf_ID'};

    }
    else {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_MISSING_PARAMETER_WF_ID"
        );

        #	$responseData->{'wf_ID'} = $session->{'wf_ID'}  ;
    }

    if ( defined $self->param("Result") ) {
        $session->{'Result'}      = $self->param("Result");
        $responseData->{'Result'} = $session->{'Result'};
    }
    else {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_MISSING_PARAMETER_RESULT"
        );
    }

    if ( defined $self->param("Reason") ) {
        $session->{'Reason'}      = $self->param("Reason");
        $responseData->{'Reason'} = $session->{'Reason'};
    }

# else
# 		{
# 			$responseData->{'error'} = "error";
# 			push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_MISSING_PARAMETER_REASON");
# 		}

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} =$errors;
        return $self->send_json_respond($responseData);
    }
#############################################################################

    if ( $session->{'Result'} eq "SUCCESS" ) {
        $action = 'scunblock_write_pin_ok';
    }
    else {
        $action = 'scunblock_write_pin_err';
    }
    $responseData->{'action'} = $action;

    $msg = $c->send_receive_command_msg(
        'execute_workflow_activity',
        {   'ID'       => $session->{'wf_ID'},
            'ACTIVITY' => $action,
            'PARAMS'   => {},
            'WORKFLOW' => $wf_type ,
        },
    );

    if ( $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_"
                . uc($action) );

    }
    else {
				push( @{$workflowtrace},
								"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_SUCCESS_WRITE_STATE");
							
#         $responseData->{'msg'}
#             = $responseData->{'msg'}
#             . "I18N_OPENXPKI_CLIENT_SUCCESS_FETCH_PUK"
#             . $session->{'cardID'};
    }

    if ( $msg->{PARAMS}->{WORKFLOW}->{STATE} eq 'SUCCESS' ) {

				push( @{$workflowtrace},
								"I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_SUCCESS_STATE_". uc($action) );
#         $responseData->{'msg'}
#             = $responseData->{'msg'}
#             . "I18N_OPENXPKI_CLIENT_SUCCESS_CAN_WRITE_PIN"
#             . $session->{'cardID'};
    }
    else {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_CONFIRM_ERROR_CHANGING_STATE"
        );
    }

    $session->{'wfstate'} = $msg->{PARAMS}->{WORKFLOW}->{STATE} ;
    $responseData->{'wfstate'} = $session->{'wfstate'};
 		$responseData->{'workflowtrace'} = $workflowtrace;
    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
    }
	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PINRESETCONFIRM_RESPONSE");
    return $self->send_json_respond($responseData);

}

#Function pinreset_cancel
#Description: set pinreset workflow state to failiure
#Required Parameter via HTTPRequest:
#		cardID  						- cardSerialNumber
#		cardType 					- CardType String
#		unblock_wfID				- Workflow ID

sub pinreset_cancel {
    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $type;
    my $wf_type = config()->{openxpki}->{pinunblock};   # $wf_pin_unblock ;
    my $msg;
    my $wf_ID;
    my $action;
	my $workflowtrace;
	my $errors	;

    $self->start_session();
    $c            = $session->{"c"};
    $responseData = $session->{"responseData"};
    $errors		= $session->{"errors"};
    $workflowtrace 	=$session->{"workflowtrace"};

 	 $responseData->{"wf_type"} = $wf_type;

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
	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PINRESETCANCEL_CALL");
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
    if ( !defined $self->param("unblock_wfID") || $self->param("unblock_wfID") eq '' ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_PINRESET_PINRESET_VERIFY_ERROR_MISSING_PARAMETER_WF_ID"
        );
    }else{
	    
	$wf_ID     = $self->param('unblock_wfID');
        $responseData->{'unblock_wfID'} = $wf_ID;
    }

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        return $self->send_json_respond($responseData);
    }




           $msg = $c->send_receive_command_msg(
            'execute_workflow_activity',
            {   'ID'       => $wf_ID,
                'ACTIVITY' => 'scunblock_user_abort',
                'PARAMS'   => {
		error_code => 'user abort'},
                'WORKFLOW' =>  $wf_type ,
            },
        );
    	$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PINRESETCANCEL_RESPONSE");
        $responseData->{'msg'} = $msg;
        return $self->send_json_respond($responseData);


}


1;

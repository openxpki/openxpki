## OpenXPKI::Client::HTML::SC::Personalization
##
## Written by Arkadius C. Litwinczuk 2010
## Copyright (C) 2010 by The OpenXPKI Project
package OpenXPKI::Client::HTML::SC::Personalization;

#common sense
use strict;
use warnings "all";

#use utf8;
use English;

use JSON;
use OpenXPKI::Client;
use OpenXPKI::Serialization::Simple;
use Crypt::CBC;
use MIME::Base64;
use Config::Std;
use OpenXPKI::i18n qw( i18nGettext );
use Data::Dumper;
use Log::Log4perl qw(:easy);
use OpenXPKI::Client::HTML::SC::Dispatcher qw( config );

use base qw(
  Apache2::Controller
  Apache2::Request
  OpenXPKI::Client::HTML::SC
);

use Apache2::Const -compile => qw( :http );

#Only these functions can be called via HTTP/Perlmod
sub allowed_methods {
	qw( server_personalization)
}    #only these functions can be called via handler

sub server_personalization {

	my ($self)    = @_;
	my $sessionID = $self->pnotes->{a2c}{session_id};
	my $session   = $self->pnotes->{a2c}{session};
	my $responseData;
	my $c       = 0;
	my $wf_type = config()->{openxpki}->{personalization};
	my $keysize = config()->{card}->{keysize};
	#Default value if not configured 
	if($keysize eq ''){
		$keysize = 2048;
	}

	my $msg;
	my @certs;

	#my $AUTHUSER  = 'selfservice';
	my $wf_ID     = undef;
	my $wf_action = '';
	my $activity;
	my %params;
	my $serverPIN = undef;
	my $serverPUK = undef;
	my $oldState;
	my $serializer     = OpenXPKI::Serialization::Simple->new();
	my $local_wf_state = '';
	my $plugincommand = '';

	my $certs_to_install_serialized;
	my $certs_to_delete_serialized;
	my $certs_to_install;
	my $certs_to_delete;
	my $certificate_to_install;
	my $chipserial;
	my $ssousername;

###########################INIT##########################
	$self->start_session();
	$c            = $session->{"c"};              #OpenXPKI socket connection
	$responseData = $session->{"responseData"};
	my $errors        = $session->{"errors"};
	my $workflowtrace = $session->{"workflowtrace"};

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
	
	    if ( defined $self->{r}->headers_in()->get('ct-remote-user')
        && $self->{r}->headers_in()->get('ct-remote-user') ne '' )
    {        
    	$ssousername = $self->{r}->headers_in()->get('ct-remote-user');

    }

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

#########################################################

####If error occured cancel request and send back error MSGs####
	if ( defined $responseData->{'error'} ) {
		$responseData->{'errors'} = @{$errors};
		return $self->send_json_respond($responseData);
	}

#########################Parse Input parameter###########

	$responseData->{'found_wf_ID'} = $self->param("perso_wfID");

	if (   defined $self->param("perso_wfID")
		&& ( $self->param("perso_wfID") ne 'undefined' )
		&& ( $self->param("perso_wfID") ne '' ) )
	{
		$wf_ID = $self->param("perso_wfID");
		$log->info(
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSONALIZATION: " . $wf_ID );
		if ( $wf_ID =~ /^[0-9]+$/ ) {

		}
		else {
			$wf_ID = undef;
		} 

	}

	if ( defined $self->param("Reason") ) {
		$session->{'Reason'}      = $self->param("Reason");
		$responseData->{'Reason'} = $session->{'Reason'};
	}
	
	
    if ( defined $self->param("ChipSerial") ) {
    	$log->info("smartcard chipserial " . $self->param("ChipSerial") );
    	$chipserial = $self->param("ChipSerial"); 
    
    }
	

CERTS:
    for ( my $i = 0; $i < 15; $i++ ) {
    	my $index = sprintf("%02d", $i);
        last CERTS if !defined $self->param( "cert$index" );
          push(@certs , $self->param( "cert$index" ) );
    }

	my $certsoncard = join( ';', @certs );

##################################Start new Perso WF############################################
	if ( !defined $wf_ID ) {

		$log->info(
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_CREATE_PERSONALIZATION_WORKFLOW");
		%params = (
			'WORKFLOW' => $wf_type,
			'PARAMS'   => {
				'certs_on_card' => $certsoncard,
				'user_id'      => $ssousername,
				'token_id'      => $session->{'id_cardID'},
				'chip_id'		=> $chipserial,
				
			},
		);

		$msg =
		  $c->send_receive_command_msg( 'create_workflow_instance', \%params, );

		if ( $self->is_error_response($msg) ) {
			$responseData->{'error'} = "error";
			push(
				@{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_CREATE_PERSONALIZATION_WORKFLOW"
			);
			$log->error(
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_CREATE_PERSONALIZATION_WORKFLOW"
			);

		}
		else {

			push(
				@{$workflowtrace},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_CREATE_PERSONALIZATION_WORKFLOW"
			);
			$log->error(
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_CREATED_PERSONALIZATION_WORKFLOW"
			);

			$responseData->{'msg'} = $msg;

# $certs_to_install_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_install};
# $certs_to_delete_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_delete};
# $responseData->{'certs_to_install_serialized'}=  $certs_to_install_serialized;
# $responseData->{'certs_to_delete_serialized'}=  $certs_to_delete_serialized;

	#$certs_to_install = $serializer->deserialize($certs_to_install_serialized);
	#$certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);
			$responseData->{'perso_wfID'} = $wf_ID =
			  $msg->{PARAMS}->{WORKFLOW}->{ID};
			$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
			$log->info(
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_CREATE_PERSONALIZATION_WORKFLOW_ID :"
				  . $responseData->{'perso_wfID'} );
			$log->info(
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_CREATE_PERSONALIZATION_WORKFLOW_STATE :"
				  . $responseData->{'wf_state'} );

		}

	}

#####################################WF actions#####################################################


	if ( defined $self->param("wf_action") && $self->param("wf_action") ne '' )
	{
		$wf_action = $self->param("wf_action");
		$log->info( "I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSONALIZATION_ACTION:"
			  . $wf_action
			  . " WFID_"
			  . $wf_ID );
	}
	
	if ( $wf_action eq 'prepare' ) {
		$log->info("wf_action:".$wf_action);
		my $res = $self->param("Result");
		$log->info("wf_action result: ".$res);
		if( defined $res &&  $res eq 'SUCCESS'){
		
		    if(! defined $session->{'tmp_rndPIN'} || $session->{'tmp_rndPIN'} eq '')
		    {
		    	$log->error('I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSONALIZATION_ERROR_INSTALLING_RNDPIN');
		    }else{
		    	$log->info('I18N_OPENXPKI_CLIENT_WEBAPI_SC_PERSONALIZATION_INSTALLED_RNDPIN');
		    	$session->{'rndPIN'} = $session->{'tmp_rndPIN'};
		    }
		}else{
			$log->info("wf_action reason: ".$self->param("Reason"));

		}
  
	}
	
		
	if ( $wf_action eq 'install_puk' ) {
		$log->info("wf_action:".$wf_action);
		my $res = $self->param("Result");
		$log->info("wf_action result: ".$res);
		if( defined $res &&  $res eq 'SUCCESS'){
			%params = (
			'ID'       => $wf_ID,
			'ACTIVITY' => 'scpers_puk_write_ok',
			'WORKFLOW' => $wf_type,
			'PARAMS'   => {},
			);

		}else{
			$log->info("wf_action reason: ".$self->param("Reason"));
						%params = (
			'ID'       => $wf_ID,
			'ACTIVITY' => 'scpers_puk_write_err',
			'WORKFLOW' => $wf_type,
			'PARAMS'   => {},
			);
			
		}
		$msg =
		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
		  );

		if ( $self->is_error_response($msg) ) {
			$responseData->{'error'} = "error";
			push(
				@{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_STATUS"
			);
			$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_STATUS");
		}
		else {
			push(
				@{$workflowtrace},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_OK"
			);
			$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_OK");
		}
	}
	
	
	
	if ( $wf_action eq 'upload_csr' ) {
	$log->info("wf_action:".$wf_action);
	my $csr;
	my $keyid;
	my $chosenLoginID;
	
	$log->debug("PKCS10Request". $self->param('PKCS10Request'));

	if ( defined $self->param('PKCS10Request') ) {
		$csr = $self->param('PKCS10Request');
	}
	$log->debug("KeyID". $self->param('KeyID'));
	if ( defined $self->param('KeyID') ) {
		$keyid = $self->param('KeyID');
	}
	$log->debug("choosen_login". $chosenLoginID);
	if ( defined $self->param('chosenLoginID') ) {
		$chosenLoginID = $self->param('chosenLoginID');
	}
	
	if( defined $session->{'dbntloginid'} ){
		eval{
			  $log->info("LoginID:". $session->{'dbntloginid'});
			 # $log->info("LoginID:". Dumper($session->{'dbntloginid'}));
			  $log->info("LoginID:". $session->{'dbntloginid'}->{0});
		};
		##FIXME Always use first ID regardless of number of ID'S
		$chosenLoginID = $session->{'dbntloginid'}->[0]; 
				
		
	}
	
#		# split line into 76 character long chunks
		$csr = join( "\n", ( $csr =~ m[.{1,64}]g ) );

		# add header
		$csr =
		    "-----BEGIN CERTIFICATE REQUEST-----\n" . $csr . "\n"
		  . "-----END CERTIFICATE REQUEST-----";

		$log->debug("CSR:". $csr);
		
		%params = (
			'ID'       => $wf_ID,
			'ACTIVITY' => 'scpers_post_non_escrow_csr',
			'WORKFLOW' => $wf_type,
			'PARAMS'   => {
				'pkcs10'         => $csr,
				'keyid'          => $keyid,
	#			'chosen_loginid' => $chosenLoginID
			},
		);
		
		$log->debug("params:". Dumper(%params));
	eval{
		$msg =
		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
		  );
		};
		
		if($@ ne ''){
			
			log->debug("eval error:".$@);
		}

		if ( $self->is_error_response($msg) ) {
			$responseData->{'error'} = "error";
			push(
				@{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR"
			);
			
			$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR");
			$log->debug("params:". Dumper($msg));
		}
		else {
			push(
				@{$workflowtrace},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR"
			);
			$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR");
			
		
	    }
  
	}
	
	
	if ( $wf_action eq 'install_cert' || $wf_action eq  'install_p12') {
		$log->info("wf_action:".$wf_action);
		my $res = $self->param("Result");
		$log->info("wf_action result: ".$res);
		
		
		
		if( defined $res &&  $res eq 'SUCCESS'){
			%params = (
			'ID'       => $wf_ID,
			'ACTIVITY' => 'scpers_cert_inst_ok',
			'WORKFLOW' => $wf_type,
			'PARAMS'   => {},
		);


	
		}else{
			%params = (
			'ID'       => $wf_ID,
			'ACTIVITY' => 'scpers_cert_inst_err',
			'WORKFLOW' => $wf_type,
			'PARAMS'   => {},
			);
			
			$responseData->{'error'} = "error";
			$log->error("wf_action error reason: ".$self->param("Reason"));
			$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_SMARTCARD_ACTIVITY_CERT_INSTALL");

		}
		
		$msg =
		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
		  );

		if ( $self->is_error_response($msg) ) {
			$responseData->{'error'} = "error";
			push(
			@{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK"
			);
			$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK");
		}
		else {
			push(
				@{$workflowtrace},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK"
			);
			$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK");
		}

		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
  
	}
	
	if ( $wf_action eq 'delete_cert' ) {
		$log->info("wf_action:".$wf_action);
		my $res = $self->param("Result");
			
		$log->info("wf_action result: ".$res);
		if( defined $res &&  $res eq 'SUCCESS'){
				
			%params = (
				'ID'       => $wf_ID,
				'ACTIVITY' => 'scpers_cert_del_ok',
				'WORKFLOW' => $wf_type,
				'PARAMS'   => {},
			);
	
			
	
			}else{
					%params = (
				'ID'       => $wf_ID,
				'ACTIVITY' => 'scpers_cert_del_err',
				'WORKFLOW' => $wf_type,
				'PARAMS'   => {},
				);
				$responseData->{'error'} = "error";
				$log->error("wf_action reason: ".$self->param("Reason"));
				$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_SMARTCARD_ACTIVITY_CERT_INSTALL");
			}
			
			$msg =
			  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
			  );
	
			if ( $self->is_error_response($msg) ) {
				$responseData->{'error'} = "error";
				push(
					@{$errors},
	"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_DEL_STATUS"
				);
					$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_DEL_STATUS");
			
			}
			else {
				push(
					@{$workflowtrace},
	"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_DEL_STATUS"
				);
				$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_DEL_STATUS");
			
			}
				
	  
	}
	
	


##################################WF states and commands##############################	
	if ( defined $session->{'rndPIN'} || $session->{'rndPIN'} ne '' ) {
		
		
		my $WFinfo = $self->wf_status( $c, $wf_ID , $wf_type);

		$log->debug(Dumper($WFinfo));
		
		$log->info($WFinfo->{PARAMS}->{WORKFLOW}->{STATE});
		
		$responseData->{'wf_state'} = $WFinfo->{PARAMS}->{WORKFLOW}->{STATE};
		
		if($WFinfo->{PARAMS}->{WORKFLOW}->{STATE} eq 'NEED_NON_ESCROW_CSR')
		{
				$responseData->{'action'} = 'upload_csr';
				
				$plugincommand =
				    'GenerateKeyPair;CardSerial='
				  . $session->{'cardID'}. ';UserPIN='
				  . $session->{'rndPIN'}. ';SubjectCN=' .$WFinfo->{PARAMS}->{WORKFLOW}->{CONTEXT}->{creator}
				  . ';KeyLength='.$keysize.';';
			
		}
		
		if($WFinfo->{PARAMS}->{WORKFLOW}->{STATE} eq 'CERT_TO_INSTALL')
		{
			
			$responseData->{'action'} = 'install_cert';
			
			$certificate_to_install =
 		  	$WFinfo->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certificate};
			$certificate_to_install =~
			  m{ -----BEGIN\ CERTIFICATE-----(.*?)-----END }xms;
			$certificate_to_install = $1;
			$certificate_to_install =~ s{ \s }{}xgms;
				
			$plugincommand =
				   'ImportX509;CardSerial='
				   . $session->{'cardID'} .
				   ';KeyID='.$WFinfo->{PARAMS}->{WORKFLOW}->{CONTEXT}->{keyid} .
				   ';UserPIN=' .$session->{'rndPIN'}. 
				   ';B64Data=' .$certificate_to_install. ';'; 			
		}
		
		
		if($WFinfo->{PARAMS}->{WORKFLOW}->{STATE} eq 'HAVE_CERT_TO_DELETE')
		{
			
			$responseData->{'action'} = 'delete_cert';
			

			my $cert_to_delete_id = $WFinfo->{PARAMS}->{WORKFLOW}->{CONTEXT}->{keyid};	
			
			$plugincommand =
				   'DeleteUserData;CardSerial='
				   . $session->{'cardID'}
				   .';KeyID='.$cert_to_delete_id 
				   .';UserPIN=' .$session->{'rndPIN'} 
				   .';DeleteCert=true'
				   .';DeleteKeypair=true;'; 			
		}
		
		if($WFinfo->{PARAMS}->{WORKFLOW}->{STATE} eq 'PKCS12_TO_INSTALL')
		{
			
			$responseData->{'action'} = 'install_p12';

			if ( defined $WFinfo->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64}
				&& $WFinfo->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64} ne '' )
			{
				
			}
			else {
					
				%params = (
					'ID'       => $wf_ID,
					'ACTIVITY' => 'scpers_refetch_p12',
					'WORKFLOW' => $wf_type,
					'PARAMS'   => {},
				);
	
				$msg =
				  $c->send_receive_command_msg( 'execute_workflow_activity',
					\%params, );
					
				#$log->info(Dumper($msg));	
	
				if ( $self->is_error_response($msg) ) {
					$responseData->{'error'} = "error";
					push(
						@{$errors},
	"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCH_P12_PW"
					);
					$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCH_P12_PW");
				}
				else {
					push(
						@{$workflowtrace},
	"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITYFETCH_P12_PW"
					);
					$log->info("I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITYFETCH_P12_PW");
				}
	
			}
	
			$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
	
	
			my $p12_pin = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_password};
			my  $p12     = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64};
		
			$plugincommand =
				   'ImportP12;CardSerial='
				   . $session->{'cardID'}
				   .';P12PIN='.$p12_pin 
				   .';UserPIN=' .$session->{'rndPIN'} 
				   .';B64Data=' .$p12. ';'; 			
		
		}
	}
	
#
#	if ( $wf_action eq 'fetch_puk' ) {
#		$log->info( "WFID_" . $wf_ID . " WF_ACTION" . $wf_action );
#
#		%params = (
#			'ID'       => $wf_ID,
#			'ACTIVITY' => 'scpers_fetch_puk',
#			'WORKFLOW' => $wf_type,
#			'PARAMS'   => {
#
#				# 'ACTIVITY' => 'scpers_fetch_puk',
#			},
#		);
#
#		$msg =
#		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
#		  );
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
#			);
#			push( @{$errors}, $msg );
#			$log->error(
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
#			);
#
#		}
#		else {
#
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
#			);
#
#			$responseData->{'msg'} = $msg;
#
#			$serverPUK = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk};
#			$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#			$certs_to_install_serialized =
#			  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_install};
#			$certs_to_delete_serialized =
#			  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_delete};
#			$responseData->{'certs_to_install_serialized'} =
#			  $certs_to_install_serialized;
#			$responseData->{'certs_to_delete_serialized'} =
#			  $certs_to_delete_serialized;
#
#			if ( defined $certs_to_install_serialized ) {
#				$certs_to_install =
#				  $serializer->deserialize($certs_to_install_serialized);
#			}
#			if ( defined $certs_to_delete_serialized ) {
#				$certs_to_delete =
#				  $serializer->deserialize($certs_to_delete_serialized);
#			}
#
#   # $certs_to_install = $serializer->deserialize($certs_to_install_serialized);
#   #$certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);
#
#			my $count = 0;
#
#			my $rnd;
#
#			do {
#				my $rndmsg =
#				  $c->send_receive_command_msg( 'get_random',
#					{ 'LENGTH' => 15 } );
#
#				if ( $self->is_error_response($rndmsg) ) {
#					push(
#						@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN"
#					);
#				}
#				$rnd = lc( $rndmsg->{PARAMS} );
#				$rnd =~ tr{[a-z0-9]}{}cd;
#				$count++;
#
#			} while ( length($rnd) < 8 && $count < 3 );
#			$rnd = substr( $rnd, 0, 8 );
#
#			# in order to satisfy the smartcard pin policy even in
#			# pathologic cases of the above random output generation we
#			# append a semi-random digit and character to the pin string
#			$rnd .= int( rand(10) );
#			$rnd .= chr( 97 + rand(26) );
#
#			#$responseData->{'wf_state'} =  $msg->{PARAMS}->{WORKFLOW}->{STATE};
#			#$responseData->{'perso_wfID'} = $msg->{PARAMS}->{WORKFLOW}->{ID};
#			if ( $count >= 2 ) {
#				$serverPIN = undef;
#			}
#			else {
#				my $userpin = $rnd . "\00";
#
#				my $encrypted =
#				  $c->send_receive_command_msg( 'deuba_aes_encrypt_parameter',
#					{ DATA => $userpin, } );
#
#				#FIX ME maybe handle possible exception
#				$serverPIN = $encrypted->{PARAMS};
#			}
#
#			# 		$msg =
#			# 			$client->send_receive_command_msg( 'get_workflow_info',
#			# 			{ 'WORKFLOW' => $wf_type, 'ID' => $id, } );
#
#			if ( $self->is_error_response($msg) ) {
#
#				push(
#					@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN"
#				);
#			}
#			else {
#				push(
#					@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN"
#				);
#
#			}
#
##     $msg =
##       $client->send_receive_command_msg( 'get_workflow_info',
##         { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
##     if ( $self->is_error_response($msg) ) {
##         return
##           "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATE_ERROR_CANT_GET_WORKFLOW_INFO";
##     }
##     }
#
#		}
#
#	}
#	elsif ( $wf_action eq 'upload_csr' ) {
#		my $csr;
#		my $keyid;
#		my $chosenLoginID;
#
#		if ( defined $self->param('PKCS10Request') ) {
#			$csr = $self->param('PKCS10Request');
#		}
#		if ( defined $self->param('KeyID') ) {
#			$keyid = $self->param('KeyID');
#		}
#		if ( defined $self->param('chosenLoginID') ) {
#			$chosenLoginID = $self->param('chosenLoginID');
#		}
#
#		# split line into 76 character long chunks
#		$csr = join( "\n", ( $csr =~ m[.{1,64}]g ) );
#
#		# add header
#		$csr =
#		    "-----BEGIN CERTIFICATE REQUEST-----\n" . $csr . "\n"
#		  . "-----END CERTIFICATE REQUEST-----";
#
#		%params = (
#			'ID'       => $wf_ID,
#			'ACTIVITY' => 'scpers_post_non_escrow_csr',
#			'WORKFLOW' => $wf_type,
#			'PARAMS'   => {
#				'pkcs10'         => $csr,
#				'keyid'          => $keyid,
#				'chosen_loginid' => $chosenLoginID
#			},
#		);
#
#		$msg =
#		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
#		  );
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR"
#			);
#
#			$responseData->{'msg'}        = $msg;
#			$responseData->{'perso_wfID'} = $msg->{PARAMS}->{WORKFLOW}->{ID};
#			$responseData->{'wf_state'}   = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#			$certs_to_install_serialized  =
#			  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_install};
#			$certs_to_delete_serialized =
#			  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_delete};
#
#			$responseData->{'certs_to_install_serialized'} =
#			  $certs_to_install_serialized;
#			$responseData->{'certs_to_delete_serialized'} =
#			  $certs_to_delete_serialized;
#			if ( defined $certs_to_install_serialized ) {
#				$certs_to_install =
#				  $serializer->deserialize($certs_to_install_serialized);
#			}
#			if ( defined $certs_to_delete_serialized ) {
#				$certs_to_delete =
#				  $serializer->deserialize($certs_to_delete_serialized);
#			}
#
#   # $certs_to_install = $serializer->deserialize($certs_to_install_serialized);
#   #$certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);
#		}
#
#	}
#	elsif ( $wf_action eq 'cert_inst_ok' ) {
#
#		# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
#
#		%params = (
#			'ID'       => $wf_ID,
#			'ACTIVITY' => 'scpers_cert_inst_ok',
#			'WORKFLOW' => $wf_type,
#			'PARAMS'   => {},
#		);
#
#		$msg =
#		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
#		  );
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK"
#			);
#		}
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		$responseData->{'msg'}      = $msg;
#
#	}
#	elsif ( $wf_action eq 'inst_puk_ok' ) {
#
#		# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
#		# 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		# 		$responseData->{'msg'}  = $msg;
#
#		%params = (
#			'ID'       => $wf_ID,
#			'ACTIVITY' => 'scpers_puk_write_ok',
#			'WORKFLOW' => $wf_type,
#			'PARAMS'   => {},
#		);
#
#		$msg =
#		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
#		  );
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_OK"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_OK"
#			);
#		}
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		$responseData->{'msg'}      = $msg;
#
#	}
#	elsif ( $wf_action eq 'cert_del_ok' ) {
#
#		# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
#		# 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		# 		$responseData->{'msg'}  = $msg;
#
#		%params = (
#			'ID'       => $wf_ID,
#			'ACTIVITY' => 'scpers_cert_del_ok',
#			'WORKFLOW' => $wf_type,
#			'PARAMS'   => {},
#		);
#
#		$msg =
#		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
#		  );
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_DEL_OK"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_DEL_STATUS"
#			);
#		}
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		$responseData->{'msg'}      = $msg;
#
#	}
#	elsif ( $wf_action eq 'cert_del_err' ) {
#
#		# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
#		# 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		# 		$responseData->{'msg'}  = $msg;
#
#		%params = (
#			'ID'       => $wf_ID,
#			'ACTIVITY' => 'scpers_cert_del_err',
#			'WORKFLOW' => $wf_type,
#			'PARAMS'   => {
#				'sc_error_reson' => $session->{'Reason'},
#
#			},
#		);
#
#		$msg =
#		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
#		  );
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		$responseData->{'msg'}      = $msg;
#
#	}
#	elsif ( $wf_action eq 'cert_inst_ok' ) {
#
#		# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
#
#		%params = (
#			'ID'       => $wf_ID,
#			'ACTIVITY' => 'scpers_cert_inst_ok',
#			'WORKFLOW' => $wf_type,
#			'PARAMS'   => {},
#		);
#
#		$msg =
#		  $c->send_receive_command_msg( 'execute_workflow_activity', \%params,
#		  );
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK"
#			);
#		}
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		$responseData->{'msg'}      = $msg;
#
#		$msg = $self->wf_status( $c, $wf_ID, $wf_type );
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS"
#			);
#		}
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#
#	}
#	else {
#
#		$msg = $self->wf_status( $c, $wf_ID, $wf_type );
#
#		$local_wf_state = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		$responseData->{'msg'} = $msg;
#
#  #try to resume workflow that is in state issue cert, e.g. CA was not available
#		if ( $local_wf_state eq 'ISSUE_CERT' ) {
#			%params = (
#				'ID'       => $wf_ID,
#				'ACTIVITY' => 'scpers_issue_certificate',
#				'WORKFLOW' => $wf_type,
#				'PARAMS'   => {},
#			);
#
#			$msg =
#			  $c->send_receive_command_msg( 'execute_workflow_activity',
#				\%params, );
#
#			if ( $self->is_error_response($msg) ) {
#				$responseData->{'error'} = "error";
#				push(
#					@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_ISSUE_CERTIFICATE"
#				);
#			}
#			else {
#				push(
#					@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_ISSUE_CERTIFICATE_OK"
#				);
#			}
#
#		}    #end issue certificate
#
##try to resume workflow that is in state HAVE_CERT_TO_PUBLISH, e.g. active directory was not available
#		if ( $local_wf_state eq 'HAVE_CERT_TO_PUBLISH' ) {
#			%params = (
#				'ID'       => $wf_ID,
#				'ACTIVITY' => 'scpers_publish_certificate',
#				'WORKFLOW' => $wf_type,
#				'PARAMS'   => {},
#			);
#
#			$msg =
#			  $c->send_receive_command_msg( 'execute_workflow_activity',
#				\%params, );
#
#			if ( $self->is_error_response($msg) ) {
#				$responseData->{'error'} = "error";
#				push(
#					@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_PUBLISH_CERTIFICATE"
#				);
#			}
#			else {
#				push(
#					@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_PUBLISH_CERTIFICATE_OK"
#				);
#			}
#		}
#
##try to resume workflow that is in state HAVE_CERT_TO_UNPUBLISH, e.g. active directory was not available
#		if ( $local_wf_state eq 'HAVE_CERT_TO_UNPUBLISH' ) {
#			%params = (
#				'ID'       => $wf_ID,
#				'ACTIVITY' => 'scpers_unpublish_certificate',
#				'WORKFLOW' => $wf_type,
#				'PARAMS'   => {},
#			);
#
#			$msg =
#			  $c->send_receive_command_msg( 'execute_workflow_activity',
#				\%params, );
#
#			if ( $self->is_error_response($msg) ) {
#				$responseData->{'error'} = "error";
#				push(
#					@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UNPUBLISH_CERTIFICATE"
#				);
#			}
#			else {
#				push(
#					@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UNPUBLISH_CERTIFICATE_OK"
#				);
#			}
#		}
#
#		$msg = $self->wf_status( $c, $wf_ID, $wf_type );
#
#		$local_wf_state = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#
#		#$responseData->{'msg'}  = $msg;
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS"
#			);
#		}
##}

########################### No active random PIN ############################################

	if ( !defined $session->{'rndPIN'} || $session->{'rndPIN'} eq '' ) {
		$log->info(
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_PERSONALIZATION_GET_PREPARE"
		);
		
			my $rnd;
			my $count = 0;

			do {
				my $rndmsg =
				  $c->send_receive_command_msg( 'get_random',
					{ 'LENGTH' => 15 } );

				if ( $self->is_error_response($rndmsg) ) {
					push(
						@{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN"
					);
					$log->error(
'I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN'
					);
				}

				$rnd = lc( $rndmsg->{PARAMS} );
				$rnd =~ tr{[a-z0-9]}{}cd;
				$count++;

			} while ( length($rnd) < 8 && $count < 3 );
			$rnd = substr( $rnd, 0, 8 );

			# in order to satisfy the smartcard pin policy even in
			# pathologic cases of the above random output generation we
			# append a semi-random digit and character to the pin string
			$rnd .= int( rand(10) );
			$rnd .= chr( 97 + rand(26) );
			$session->{'tmp_rndPIN'} = $rnd;

			%params = (
				'ID'       => $wf_ID,
				'ACTIVITY' => 'scpers_fetch_puk',
				'WORKFLOW' => $wf_type,
				'PARAMS'   => {},
					);

			$msg =
			  $c->send_receive_command_msg( 'execute_workflow_activity',
				\%params, );
				
	
			if ( $self->is_error_response($msg) ) {
				$responseData->{'error'} = "error";
				push(
					@{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
				);
				push( @{$errors}, $msg );
				$log->error(
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
				);

			}
			else {

				push(
					@{$workflowtrace},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
				);

		my $PUK     = $serializer->deserialize( $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk} );
				
		
		
		
		if ( $local_wf_state eq 'PUK_TO_INSTALL' ) {
			
				$responseData->{'action'} = 'install_puk';
				
				$plugincommand =
				    'ChangePUK;CardSerial='
				  . $session->{'cardID'} . ';PUK='
				  . $PUK->[1]  . 'NewPUK=' .$PUK->[0]
				  . ';';
	
		}
		else {
	#			$log->debug('PUK:' . Dumper($PUK)	);
	#			$log->debug('PUK:' . $PUK->[0]	);
				$plugincommand =
				    'ResetPIN;CardSerial='
				  . $session->{'cardID'}
				  . ';PUK='
				  . $PUK->[0]
				  . ';NewPIN='
				  . $session->{'tmp_rndPIN'} . ';';
				  
			    $responseData->{'action'} = 'prepare';

			}

		}

	}

#count how many actions certiinstalation, or deletion  are still pending to finish this personalization
#	my $count;
#
#	if ( defined $certs_to_install && defined $certs_to_delete ) {
#		$count = scalar( @{$certs_to_install} ) + scalar( @{$certs_to_delete} );
#	}
#	elsif ( defined $certs_to_install ) {
#		$count = scalar( @{$certs_to_install} );
#	}
#	elsif ( defined $certs_to_install ) {
#		$count = scalar( @{$certs_to_delete} );
#	}
#	$count += 1;    #Plus current pending action
#
#	if (
#		( defined $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certificate} )
#		&& ( $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{cert_install_type} eq
#			'x509' )
#	  )
#	{
#
#		$certificate_to_install =
#		  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certificate};
#		$certificate_to_install =~
#		  m{ -----BEGIN\ CERTIFICATE-----(.*?)-----END }xms;
#		$certificate_to_install = $1;
#		$certificate_to_install =~ s{ \s }{}xgms;
#
#	}
#
#	my $p12;
#	my $p12_pin;
#
#	if ( $responseData->{'wf_state'} eq 'PKCS12_TO_INSTALL' ) {
#		$responseData->{'pre_p12'} = $msg;
#
#		if ( $self->is_error_response($msg) ) {
#			$responseData->{'error'} = "error";
#			push(
#				@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS"
#			);
#		}
#		else {
#			push(
#				@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS"
#			);
#		}
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		if ( defined $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64}
#			&& $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64} ne '' )
#		{
#
#		}
#		else {
#			$responseData->{'refetch_p12'} = $msg;
#			%params = (
#				'ID'       => $wf_ID,
#				'ACTIVITY' => 'scpers_refetch_p12',
#				'WORKFLOW' => $wf_type,
#				'PARAMS'   => {},
#			);
#
#			$msg =
#			  $c->send_receive_command_msg( 'execute_workflow_activity',
#				\%params, );
#
#			if ( $self->is_error_response($msg) ) {
#				$responseData->{'error'} = "error";
#				push(
#					@{$errors},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCH_P12_PW"
#				);
#			}
#			else {
#				push(
#					@{$workflowtrace},
#"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITYFETCH_P12_PW"
#				);
#			}
#
#		}
#
#		$responseData->{'wf_state'} = $msg->{PARAMS}->{WORKFLOW}->{STATE};
#		$responseData->{'msg'}      = $msg;
#
#		$p12_pin = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_p12password};
#		$p12     = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64};
#
#	}
#
#	my $cert_to_delete_id = undef;
#	if ( $responseData->{'wf_state'} eq 'HAVE_CERT_TO_DELETE' ) {
#
#		$cert_to_delete_id = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{keyid};
#
#	}
#
#	if ( defined $serverPUK ) {
#		$serverPUK = $serializer->deserialize($serverPUK);
#	}

		$log->info(
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_ENCRYPT_OUT_DATA"
		);
		$log->info("Plugin command to enc:".$plugincommand);
	if ( $plugincommand ne '' ) {
		
		eval{
		$responseData->{'exec'} = $self->session_encrypt($plugincommand) ;
		};
		$log->info('action:'.$responseData->{'action'});
        $log->info('exec:'.$@.$responseData->{'exec'});
  		
		#$responseData->{'exec'} = $cipher->encrypt($plugincommand);
		#$decrypted = $cipher->decrypt($encrypted)
	}
			$log->info(
			"I18N_OPENXPKI_CLIENT_WEBAPI_SC_EXECUTE_OUT_DATA_ENCRYPTED"
		);

	$responseData->{'perso_wf_type'} = $wf_type;
	$responseData->{'perso_wfID'}    = $wf_ID;
	$responseData->{'errors'}        = $errors;
	$responseData->{'workflowtrace'} = $workflowtrace;


#################Sent out json response#####################
	return $self->send_json_respond($responseData);

}

1;


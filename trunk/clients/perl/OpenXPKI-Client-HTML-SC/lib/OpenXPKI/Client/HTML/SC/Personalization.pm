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

##Global Vars
#my $wf_pin_unblock = 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK';

#Only these functions can be called via HTTP/Perlmod
sub allowed_methods {
    qw( server_personalization)
}    #only these fucntions can be called via handler


sub server_personalization {


    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $wf_type      = config()->{openxpki}->{personalization};

    my $msg;
    my @certs;
    my $AUTHUSER  = 'selfservice';
	 my $wf_ID = undef;
	 my $wf_action = '';
	 my $activity;
	 my %params;
    my $serverPIN=undef;
    my $serverPUK=undef;
	 my $oldState;
	my $serializer = OpenXPKI::Serialization::Simple->new();

my $certs_to_install_serialized;
my $certs_to_delete_serialized; 
my $certs_to_install;
my $certs_to_delete;
my $certificate_to_install;

###########################INIT##########################
    $self->start_session();
    $c = $session->{"c"};    #OpenXPKI socket connection
    $responseData = $session->{"responseData"};
    my $errors	 	= $session->{"errors"};
    my $workflowtrace 	=$session->{"workflowtrace"};



      if (!defined $c || $c == 0)
      {
                $responseData->{'error'} = "error";
                            push(
                 @{$errors},
		"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_RESUME_SESSION_NO_CARDOWNER"
		  );

        $responseData->{'errors'} = $errors;
        return $self->send_json_respond($responseData);

      }

#   if(!defined $c || $c == 0 || $c eq ''){
# 
#      if(defined $session->{'cardOwner'} && $session->{'cardOwner'} ne ''){
# 
# 	$c = $self->openXPKIConnection(
# 			$session->{'openxPKI_Session_ID'} ,
# 			$session->{'cardOwner'},
# 			config()->{openxpki}->{role}
# 		    );
# 	
# 	if ( !defined $c ) {
# 
# 		# die "Could not instantiate OpenXPKI client. Stopped";
# 
# 		$responseData->{'error'} = "error";
# 		push(
# 		    @{$errors},
# 	      "I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI_SESSION_CONTINUE_FAILED"
# 		);
# 		$c = 0;
# 
# 	    }
# 	    else {
# 
# 		if ( $c != 0 ) {
# 		    $session->{'openxPKI_Session_ID'} = $c->get_session_id();
# 		    $responseData->{'start_new_user_session'} = "OpenXPKISession perso resume session";
# 		}
# 	   }
# 	 
#       }else
#       {
# 		$responseData->{'error'} = "error";
# 		push(
# 		    @{$errors},
# 	      "I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_ERROR_RESUME_SESSION_NO_CARDOWNER"
# 		);
# 		$c = 0;
# 
# 	    $responseData->{'cardOwner'}  = $session->{'cardOwner'};
# 	  $responseData->{'errors'}  = $errors;
# 	  $responseData->{'workflowtrace'}  = $workflowtrace;
# 	  $session->{'responseData'} = $responseData;
# 
#  
# 	  return $self->send_json_respond($responseData);
# 
# 
#       }
#     }

#########################################################

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = @{$errors};
        return $self->send_json_respond($responseData);
    }


#########################Parse Input parameter###########

    if ( defined $self->{r}->headers_in()->get('ct-remote-user') ) {
        $AUTHUSER = $self->{r}->headers_in()->get('ct-remote-user');
    }
    $responseData->{'cardOwner'} = $session->{'cardOwner'};	

	 $responseData->{'found_wf_ID'} =  $self->param("perso_wfID");
    if ( defined $self->param("perso_wfID") && ( $self->param("perso_wfID") ne 'undefined' ) && ( $self->param("perso_wfID") ne '' ) ) {
	 # if ( defined $self->param("perso_wfID") ) {
        $wf_ID = $self->param("perso_wfID");
			if($wf_ID =~ /^[0-9]+$/){
				
			}else{
				$wf_ID = undef;
			}
       
    }

   if ( defined $self->param("Reason") ) {
        $session->{'Reason'}      = $self->param("Reason");
        $responseData->{'Reason'} = $session->{'Reason'};
    }
    #$responseData->{'cardID'} = $self->param("cardID");
    #$responseData->{'cert0'}  = $self->param("cert0");
   #$responseData->{'Result'} = $self->param("Result");

CERTS:
    for ( my $i = 0; $i < 15; $i++ ) {
        last CERTS if !defined $self->param( "cert".$i );
        push( @certs, $self->param( "cert".$i ) );

    }

    my $certsoncard = join(';', @certs);


if( !defined $wf_ID )
{
    %params = (
        'WORKFLOW' => $wf_type,
	    'PARAMS' => {
	    'certs_on_card' => $certsoncard,
	    'login_id'    => $AUTHUSER ,
	    'token_id'    => $session->{'id_cardID'},
	},
	);

    $msg = $c->send_receive_command_msg( 'create_workflow_instance', \%params, );

    if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_CREATE_PERSONALIZATION_WORKFLOW"
                );

    }else
	 {

         push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_CREATE_PERSONALIZATION_WORKFLOW"
                );

   	 $responseData->{'msg'} = $msg;

	    $certs_to_install_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_install};
	    $certs_to_delete_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_delete}; 
		 $responseData->{'certs_to_install_serialized'}=  $certs_to_install_serialized;
		 $responseData->{'certs_to_delete_serialized'}=  $certs_to_delete_serialized;


	   # $certs_to_install = $serializer->deserialize($certs_to_install_serialized);
	    #$certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);
   	 $responseData->{'perso_wfID'} = $msg->{PARAMS}->{WORKFLOW}->{ID};
		 $responseData->{'wf_state'} =  $msg->{PARAMS}->{WORKFLOW}->{STATE};
	}

}else
{

    if ( defined $self->param("wf_action") &&  $self->param("wf_action") ne '' ) {
        $wf_action= $self->param("wf_action");
    }


if($wf_action eq 'fetch_puk'){

    %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_fetch_puk',
        'WORKFLOW' => $wf_type,
	    'PARAMS' => {
               # 'ACTIVITY' => 'scpers_fetch_puk',
	},
	);
	

    $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );

    if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
               );
        push( @{$errors},$msg );

    }else
	 {

      
         push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCHPUK"
                );



 		$responseData->{'msg'} = $msg;
		$serverPUK =  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_puk};
 		$responseData->{'wf_state'} =  $msg->{PARAMS}->{WORKFLOW}->{STATE};
	    $certs_to_install_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_install};
	    $certs_to_delete_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_delete}; 
		$responseData->{'certs_to_install_serialized'}=  $certs_to_install_serialized;
		$responseData->{'certs_to_delete_serialized'}=  $certs_to_delete_serialized;

		if(defined $certs_to_install_serialized)
		{
			$certs_to_install = $serializer->deserialize($certs_to_install_serialized);	
		}
		if(defined $certs_to_delete_serialized)
		{
         $certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);
		}
	   # $certs_to_install = $serializer->deserialize($certs_to_install_serialized);	
	    #$certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);

		my $count=0;

		my $rnd;

		do {
			my $rndmsg =  $c->send_receive_command_msg( 'get_random', { 'LENGTH' => 15});

			if ( $self->is_error_response($rndmsg) ) {
        		push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN");
    		}
			$rnd = lc($rndmsg->{PARAMS});
			$rnd =~ tr{[a-z0-9]}{}cd;
			$count++;

		} while (length($rnd) < 8 && $count < 3);
		$rnd = substr($rnd,0,8);
		# in order to satisfy the smartcard pin policy even in 
		# pathologic cases of the above random output generation we
		# append a semi-random digit and character to the pin string
		$rnd .= int(rand(10));
		$rnd .= chr(97 +  rand(26));
		
		
   	#$responseData->{'wf_state'} =  $msg->{PARAMS}->{WORKFLOW}->{STATE};
		#$responseData->{'perso_wfID'} = $msg->{PARAMS}->{WORKFLOW}->{ID};
		if($count >= 2)
		{
			$serverPIN = undef;
		}
		else{
			my $userpin = $rnd."\00";
			
			my $encrypted = $c->send_receive_command_msg( 'deuba_aes_encrypt_parameter' ,{
				DATA => $userpin,
			});
			
 			#FIX ME maybe handle possible exception
			$serverPIN = $encrypted->{PARAMS};
		}
		

# 		$msg =
# 			$client->send_receive_command_msg( 'get_workflow_info',
# 			{ 'WORKFLOW' => $wf_type, 'ID' => $id, } );
			if ( $self->is_error_response($msg) ) {

			   push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN"
                );
			}else{
			  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GETRNDPIN"
                );


		}
#     $msg =
#       $client->send_receive_command_msg( 'get_workflow_info',
#         { 'WORKFLOW' => $wf_type, 'ID' => $id, } );
#     if ( $self->is_error_response($msg) ) {
#         return
#           "I18N_OPENXPKI_CLIENT_WEBAPI_SC_WFSTATE_ERROR_CANT_GET_WORKFLOW_INFO";
#     }
#     }

	 }

}elsif ($wf_action eq 'upload_csr'){
my $csr;
my $keyid;
my $chosenLoginID;

  if ( defined $self->param('PKCS10Request') ) {
        $csr = $self->param('PKCS10Request');
    }
  if ( defined $self->param('KeyID') ) {
        $keyid = $self->param('KeyID');
    }
  if ( defined $self->param('chosenLoginID') ) {
        $chosenLoginID = $self->param('chosenLoginID');
    }


# split line into 76 character long chunks
$csr = join("\n", ($csr =~ m[.{1,64}]g));

# add header
$csr = "-----BEGIN CERTIFICATE REQUEST-----\n"
. $csr . "\n"
. "-----END CERTIFICATE REQUEST-----";

    %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_post_non_escrow_csr',
        'WORKFLOW' => $wf_type,
	    'PARAMS' => {
               'pkcs10' =>$csr ,
					'keyid' =>$keyid,
					'chosen_loginid' => $chosenLoginID
	},
	);
	


 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );

    if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR"
              );
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UPLOAD_CSR"
                );

       $responseData->{'msg'} = $msg ;
   	 $responseData->{'perso_wfID'} = $msg->{PARAMS}->{WORKFLOW}->{ID};
		 $responseData->{'wf_state'} =  $msg->{PARAMS}->{WORKFLOW}->{STATE};
	    $certs_to_install_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_install};
	    $certs_to_delete_serialized = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certs_to_delete}; 

$responseData->{'certs_to_install_serialized'}=  $certs_to_install_serialized;
$responseData->{'certs_to_delete_serialized'}=  $certs_to_delete_serialized;
		if(defined $certs_to_install_serialized)
		{
			$certs_to_install = $serializer->deserialize($certs_to_install_serialized);	
		}
		if(defined $certs_to_delete_serialized)
		{
         $certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);
		}

	   # $certs_to_install = $serializer->deserialize($certs_to_install_serialized);
	    #$certs_to_delete = $serializer->deserialize($certs_to_delete_serialized);
	 }


}elsif ($wf_action eq 'get_status'){
  	$msg = $self->wf_status( $c,  $wf_ID , $wf_type);

	$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
	$responseData->{'msg'}  = $msg;

#try to resume workflow that is in state issue cert, e.g. CA was not available  
	if($responseData->{'wf_state'} eq 'ISSUE_CERT'){
	      %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_issue_certificate',
        'WORKFLOW' => $wf_type,
	     'PARAMS' => {},
	);

 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );

   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_ISSUE_CERTIFICATE");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_ISSUE_CERTIFICATE_OK");
	 }

    }#end issue certificate

#try to resume workflow that is in state HAVE_CERT_TO_PUBLISH, e.g. active directory was not available  
	if($responseData->{'wf_state'} eq 'HAVE_CERT_TO_PUBLISH'){
	      %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_publish_certificate',
        'WORKFLOW' => $wf_type,
	     'PARAMS' => {},
	);

 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );

   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_PUBLISH_CERTIFICATE");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_PUBLISH_CERTIFICATE_OK");
	 }
    }

#try to resume workflow that is in state HAVE_CERT_TO_UNPUBLISH, e.g. active directory was not available  
	if($responseData->{'wf_state'} eq 'HAVE_CERT_TO_UNPUBLISH'){
	      %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_unpublish_certificate',
        'WORKFLOW' => $wf_type,
	     'PARAMS' => {},
	);

 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );

   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UNPUBLISH_CERTIFICATE");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_UNPUBLISH_CERTIFICATE_OK");
	 }
    }


	$msg = $self->wf_status( $c,  $wf_ID , $wf_type);

	$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
	$responseData->{'msg'}  = $msg;

    if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS"
                );
	 }
	


}elsif ($wf_action eq 'cert_inst_ok'){
# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);

    %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_cert_inst_ok',
        'WORKFLOW' => $wf_type,
	     'PARAMS' => {
	},
	);

 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );

   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_INST_OK");
	 }
	

 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
 		$responseData->{'msg'}  = $msg;
	

}elsif ($wf_action eq 'inst_puk_ok'){
# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
# 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
# 		$responseData->{'msg'}  = $msg;

    %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_puk_write_ok',
        'WORKFLOW' => $wf_type,
	     'PARAMS' => {			
	},
	);

 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );


   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_OK");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_WRITE_PUK_OK");
	 }

 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
 		$responseData->{'msg'}  = $msg;


}elsif ($wf_action eq 'cert_del_ok'){
# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
# 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
# 		$responseData->{'msg'}  = $msg;
	
    %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_cert_del_ok',
        'WORKFLOW' => $wf_type,
	     'PARAMS' => {
	},
	);

 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );


   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_CERT_DEL_OK");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_DEL_STATUS");
	 }

 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
 		$responseData->{'msg'}  = $msg;


}elsif ($wf_action eq 'cert_del_err'){
# 		$msg = $self->wf_status( $c,  $wf_ID , $wf_type);
# 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
# 		$responseData->{'msg'}  = $msg;
	
    %params = (
			'ID' => $wf_ID ,
			'ACTIVITY' => 'scpers_cert_del_err',
        'WORKFLOW' => $wf_type,
	     'PARAMS' => {
 				'sc_error_reson' =>$session->{'Reason'} ,
			
	},
	);

 $msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );

 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
 		$responseData->{'msg'}  = $msg;


}else{



    $msg = $self->wf_status( $c,  $wf_ID , $wf_type);


   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS");
	 }

		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
		$responseData->{'msg'}  = $msg;

}

#count how many actions certiinstalation, or deletion  are still pending to finish this personalization
my $count;


if(defined $certs_to_install && defined $certs_to_delete)
{
$count = scalar(@{$certs_to_install}) + scalar(@{$certs_to_delete});
}elsif(defined $certs_to_install){
$count = scalar(@{$certs_to_install});
}elsif(defined $certs_to_install){
$count = scalar(@{$certs_to_delete});
}
$count += 1; #Plus current pending action 

	if( (defined $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certificate} ) && ( $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{cert_install_type} eq 'x509' ) ){

	$certificate_to_install =  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certificate};
			$certificate_to_install =~ m{ -----BEGIN\ CERTIFICATE-----(.*?)-----END }xms;
			$certificate_to_install = $1;
			$certificate_to_install =~ s{ \s }{}xgms;

}	


my $p12;
my $p12_pin;

if($responseData->{'wf_state'} eq 'PKCS12_TO_INSTALL')
{
	$responseData->{'pre_p12'} = $msg;

   if (  $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS");
    }else
	 {
		  push( @{$workflowtrace},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_GET_STATUS");
	 }

	 $responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
	if(defined $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64} && $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64} ne '')
	{

	}else{
	   $responseData->{'refetch_p12'} = $msg;
		%params = (
				'ID' => $wf_ID ,
				'ACTIVITY' => 'scpers_refetch_p12',
			'WORKFLOW' => $wf_type,
			'PARAMS' => {
		},
		);
	
	$msg = $c->send_receive_command_msg( 'execute_workflow_activity', \%params, );
	
	
		if (  $self->is_error_response($msg) ) {
			$responseData->{'error'} = "error";
			push( @{$errors},
					"I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITY_FETCH_P12_PW");
		}else
		{
			push( @{$workflowtrace},
					"I18N_OPENXPKI_CLIENT_WEBAPI_SC_SUCCESS_EXECUTE_PERSONALIZATION_WORKFLOW_ACTIVITYFETCH_P12_PW");
		}

	}



 		$responseData->{'wf_state'}  = $msg->{PARAMS}->{WORKFLOW}->{STATE};
 		$responseData->{'msg'}  = $msg;
		
		$p12_pin =  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_p12password};
		$p12     =  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{_pkcs12base64};
#$responseData->{'foo'}  = 'bar';

}

my $cert_to_delete_id=undef;
if($responseData->{'wf_state'} eq 'HAVE_CERT_TO_DELETE')
{
	
		$cert_to_delete_id =  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{keyid};

}

		if(defined $serverPUK)
		{
			$serverPUK = $serializer->deserialize($serverPUK);
		}
	
	$responseData->{'cert'} = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{certificate} ;
	$responseData->{'cert_type'} = $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{cert_install_type}  ;
	$responseData->{'p12'} = $p12;
	$responseData->{'p12_p'} = $p12_pin;
	$responseData->{'cert_id_to_delete'}  = $cert_to_delete_id;


	$responseData->{'cert_to_install'} =  $certificate_to_install; 
	$responseData->{'cert_install_type'} =  $msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{cert_install_type}; 
	$responseData->{'pending_operations'} =  $count; 
	$responseData->{'perso_wf_type'} =  $wf_type; 
 	$responseData->{'perso_wfID'} = $wf_ID;
	$responseData->{'serverPIN'} = $serverPIN ;
	$responseData->{'serverPUK'} = $serverPUK ;
   $responseData->{'errors'}  = $errors;
	$responseData->{'workflowtrace'}  = $workflowtrace;
   $session->{'responseData'} = $responseData;


}
 	#$responseData->{'msg'} = $msg;
#################Sent out json response#####################
    return $self->send_json_respond($responseData);




}

1;

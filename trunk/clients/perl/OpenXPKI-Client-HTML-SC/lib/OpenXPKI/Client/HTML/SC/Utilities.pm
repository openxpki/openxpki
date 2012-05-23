## OpenXPKI::Client::HTML::SC::Utilities
##
## Written by Arkadius C. Litwinczuk 2010
## Copyright (C) 2010 by The OpenXPKI Project
package OpenXPKI::Client::HTML::SC::Utilities;

#common sense
use strict;
use warnings "all";

#use utf8;
use English;

use JSON;
use OpenXPKI::Client;

use Config::Std;
use OpenXPKI::i18n qw( i18nGettext );
use Data::Dumper;
use OpenXPKI::Client::HTML::SC::Dispatcher qw( config );
use DateTime;
use Log::Log4perl qw(:easy);
use Digest::SHA qw (sha256_hex);
use Crypt::ECDH;
use Crypt::OpenSSL::AES;


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
    qw( get_card_status encrypt_pin get_server_status server_log)
}    #only these fucntions can be called via handler

#Function 

#echo JSON msg
#Required Parameter via HTTPRequest:
#		cardID  				- cardSerialNumber
#		cardType 			- CardType String
#Optional Parameter via HTTPRequest:
#		cert[int]					- certificates cert0 ,cert1 etc.
# 		AUTHUSER						- loged in user name
sub get_card_status {
    my ($self)    = @_;
    my $sessionID = $self->pnotes->{a2c}{session_id};
    my $session   = $self->pnotes->{a2c}{session};
    my $c = 0;
    my $errors;
    my $msg;
    my @certs;
    my $AUTHUSER;
    my $chipserial;

###########################INIT##########################
    $self->start_session();
    $c = $session->{"c"};    #OpenXPKI socket connection
    my $responseData = $session->{"responseData"};
    $errors				= $session->{"errors"};
 	 my $workflowtrace 	=$session->{"workflowtrace"};
#########################################################
#$responseData = $session->{"responseData"};
# $responseData->{'c'} = Dumper($session->{"c"});
# $responseData->{'a2csessionid'} = $self->pnotes->{a2c}{session_id};
# return $self->send_json_respond($responseData);
#########################Parse Input parameter###########
    # 	if(! defined $self->param("msg") )
    # 	{
    # 		$responseData->{'error'} = "error";
    # 		push(@errors,"No msg defined");
    # 	}else{
    # 		$responseData->{'usermsg'} =  $self->param("msg") ;
    # 	}
    if(Log::Log4perl->initialized()) {
        # Yes, Log::Log4perl has already been initialized
        $responseData->{'log4perl init'} = "YES";
    } else {
   		 Log::Log4perl->init_once("/var/applications/apache/pki/conf/log.conf");
        # No, not initialized yet ...
         $responseData->{'log4perl init'} = "NO";
    }
    

   my $log = Log::Log4perl->get_logger("openxpki.smartcard");
   $log->info("Get smartcard status " . $session->{'id_cardID'} );
   
    if ( defined $self->{r}->headers_in()->get('ct-remote-user') && $self->{r}->headers_in()->get('ct-remote-user') ne '') {
        $AUTHUSER = $self->{r}->headers_in()->get('ct-remote-user');
    }
    
    $log->info("smartcard chipserial " . $self->param("ChipSerial") );
    if ( defined $self->param("ChipSerial") ) {
    	
    	$chipserial = $self->param("ChipSerial"); 
    
    }

    $responseData->{'Result'} = $self->param("Result");
CERTS:
    for ( my $i = 0; $i < 15; $i++ ) {
    	my $index = sprintf("%02d", $i);
        last CERTS if !defined $self->param( "cert$index" );
        push(@certs , $self->param( "cert$index" ) );
    }

#########################################################

####If error occured cancel request and send back error MSGs####
    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = @{$errors};
        return $self->send_json_respond($responseData);
    }

    my %params = (
        'CERTS'          => \@certs,
        'CERTFORMAT'     => 'BASE64',
        'WORKFLOW_TYPES' => [config()->{openxpki}->{pinunblock}, config()->{openxpki}->{personalization} ],
        'SMARTCARDID'    => $session->{'id_cardID'},
        'SMARTCHIPID'    => $chipserial,
        
    );
    if ( defined $AUTHUSER ) {
        $params{USERID} = $AUTHUSER;
    }
if(( !defined $c || $c == 0 || $c eq '' ) && (!defined $session->{'cardOwner'} ||  $session->{'cardOwner'} eq '') ){
$responseData->{'c'} = Dumper($c);
$responseData->{'sc'} = Dumper($session->{"c"});

}


  if(( !defined $c || $c == 0 || $c eq '' ) && (!defined $session->{'cardOwner'} ||  $session->{'cardOwner'} eq '') ){
    $c = $self->openXPKIConnection(
                     undef,
                     config()->{openxpki}->{user},
                     config()->{openxpki}->{role}
                 );
    
     if ( !defined $c ) {

            # die "Could not instantiate OpenXPKI client. Stopped";

            $responseData->{'error'} = "error";

            push(
                @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI_SESSION_CONTINUE_FAILED"
            );
            $c = 0;

        }
        else {

	    if( $c ne 'I18N_OPENXPKI_CLIENT_WEBAPI_SC_OPENXPKICONNECTION_ERROR'){

            if ( $c != 0 ) {
            	$session->{'openxPKI_Session_ID'} = $c->get_session_id();
                $responseData->{'start_selfserv_user_session'} = "OpenXPKISession started new selfverv User session";
            }else{
	      $responseData->{'error'} = "error";
	      push(
		  @{$errors},
		  "I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI"
	      );
	      $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI" .$session->{'id_cardID'} );
	      $c = 0;
	      $responseData->{'errors'} = $errors;
	      return $self->send_json_respond($responseData);
	    }



	}else
	{
	
	      $responseData->{'error'} = "error";
            push(
                @{$errors},
		"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI"
            );
             $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI"); 
            $c = 0;
	    $responseData->{'errors'} = $errors;
	    return $self->send_json_respond($responseData);

	}
        }
    }
    
	eval{
    $msg = $c->send_receive_command_msg( 'sc_analyze_smartcard', \%params, );
    	};
    	
   # $log->info("label:" . Dumper($msg->{LIST})  ); 	
	# $log->info(Dumper($msg)); 
	
    if ( $self->is_error_response($msg) ) {
    	
    	$log->info("label: ". $msg->{LIST}->[0]->{'LABEL'});
    	
    	if( $msg->{LIST}->[0]->{'LABEL'} eq "I18N_OPENXPKI_SERVER_API_SMARTCARD_SC_ANALYZE_SMARTCARD_SEARCH_PERSON_FAILED" ){
        	        push( @{$errors},
            "I18N_OPENXPKI_SERVER_API_SMARTCARD_SC_ANALYZE_SMARTCARD_SEARCH_PERSON_FAILED" );
        $log->error("I18N_OPENXPKI_SERVER_API_SMARTCARD_SC_ANALYZE_SMARTCARD_SEARCH_PERSON_FAILED"); 
        
        }else{
        	$responseData->{'error'} = "error";
      
        	push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_GET_CARD_STATUS" );
        	$log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_GET_CARD_STATUS");
        }      
        
  
	 }
	 
	
#########################################################

	if(defined $self->param("ECDHPubkey")){
		$session->{'rndPIN'} = undef ;
	
	 	$log->info("ECDHPeerPubkey:\n " . $self->param("ECDHPubkey") );
	 	my $ECDHPeerPubkey = $self->param("ECDHPubkey");
	 	$ECDHPeerPubkey =~ s/^\s+//;
		$ECDHPeerPubkey =~ s/\s+$//;
	   # $log->info("ECDHPeerPubkey:\n " . $ECDHPeerPubkey );

	    my $ecdhkey;
		eval{
	 		$ecdhkey =  Crypt::ECDH::get_ecdh_key($ECDHPeerPubkey);
	 	};
	 	if( $@ ne ''){
	 			$log->error("Crypt::ECDH::get_ecdh_key:" . $@ );
	 	}
	 	
	 	$log->info("ECDHPubkey:\n " . $ecdhkey->{'PEMECPubKey'} );
	 	$session->{'ECDHPeerPubkey'} =  $ECDHPeerPubkey ;
	 	$session->{'ECDHPubkey'} =  $ecdhkey->{'PEMECPubKey'} ;
	 	$session->{'PEMECKey'} = $ecdhkey->{'PEMECKey'};
	 	$session->{'ECDHkey'} = $ecdhkey->{'ECDHKey'};
	 	
	 	
	 	$responseData->{'ecdhpubkey'} = $ecdhkey->{'PEMECPubKey'};
	 	
	 	$session->{'aeskey'} = sha256_hex($ecdhkey->{'ECDHKey'});
	 	
	 	#$log->debug("AESKey:\n ".$session->{'aeskey'} );

	}






###close openxpki connection and reopen with  card owner as usernam####

if(!defined $session->{'cardOwner'} || $session->{'cardOwner'} eq '') {
    $self->disconnect($c);	 
    
  
	$session->{'creator_userID'} = $msg->{PARAMS}->{SMARTCARD}->{assigned_to}->{workflow_creator};
	$session->{'cardOwner'} = $msg->{PARAMS}->{SMARTCARD}->{assigned_to}->{workflow_creator};
	$session->{'dbntloginid'} = $msg->{PARAMS}->{SMARTCARD}->{assigned_to}->{loginids};
	$session->{'outlook_displayname'} = config()->{outlook}->{displayname};
	$session->{'outlook_b64'} = config()->{outlook}->{b64};
	$session->{'outlook_issuerCN'} = config()->{outlook}->{issuerCN};
    $log->debug("Card owner: ". $session->{'cardOwner'} );
   # $log->debug("dbntloginid: ". Dumper( $session->{'dbntloginid'}) );
    #$log->debug("dbntloginid: ". Dumper( $session->{'dbntloginid'}->[0]) );
    
 	 $c = $self->openXPKIConnection(
                undef,
                $session->{'cardOwner'},
                config()->{openxpki}->{role}
         );
     
     if ( !defined $c ) {

            # die "Could not instantiate OpenXPKI client. Stopped";

            $responseData->{'error'} = "error";
            push(
                @{$errors},
"I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI_SESSION_CONTINUE_FAILED"
            );
            $c = 0;
                    $log->error("I18N_OPENXPKI_CLIENT_WEBAPI_SC_START_SESSION_ERROR_CANT_CONNECT_TO_PKI_SESSION_CONTINUE_FAILED"); 

        }
        else {

            if ( $c != 0 ) {
            	$session->{'openxPKI_Session_ID'} = $c->get_session_id();
                $responseData->{'start_new_user_session'} = "OpenXPKISession started new User session";
            }
        }
  }
         
 
 
 
 #########################################################
 ##########fetch workflow information ##################
     
         
 	my $activeworkflows = $msg->{PARAMS}->{WORKFLOWS} ;

my @activewf;
	
foreach my $wf_type (keys %{$activeworkflows}) {
	ENTRY:
	foreach my $entry (@{$activeworkflows->{$wf_type}}) {
		my %newentry;
		foreach my $key (keys %{$entry}) {
			my $newkey = $key;
			$newkey =~ s{ \A WORKFLOW\. }{}xms;
			$newentry{$newkey} = $entry->{$key};
		}
		my $isodate = $entry->{'WORKFLOW.WORKFLOW_LAST_UPDATE'};
		my ($yy, $mm, $dd, $hh, $min, $sec) = ($isodate =~ m{ \A (\d+)-(\d+)-(\d+) \s+ (\d+):(\d+):(\d+) }xms);
		my $last_update = DateTime->new(
			year => $yy,
			month => $mm,
			day => $dd,
			hour => $hh,
			minute => $min,
			second => $sec,
			time_zone => 'UTC',
		);

		if($newentry{'WORKFLOW_TYPE'} eq config()->{openxpki}->{pinunblock})
		{
			if( ($newentry{'WORKFLOW_STATE'} ne 'SUCCESS') and ( $newentry{'WORKFLOW_STATE'} ne 'FAILURE' ) ){

			my $unblock_msg =
				$c->send_receive_command_msg( 'get_workflow_info',
				{ 'WORKFLOW' => config()->{openxpki}->{pinunblock}  , 'ID' => $newentry{'WORKFLOW_SERIAL'} } );
			
			if ( $self->is_error_response($msg) ) {
		
				#$@ = "Error running get_workflow_info: " . Dumper($msg);  #fix me i18n
				#$responseData->{'error'} = "error";
				push(
						@{$errors},
						"I18N_OPENXPKI_CLIENT_SC_UTILITIES_ERROR_GETTING_WORKFLOW_INFO"
				);
				push( @{$errors}, $msg );
			}else{
				$newentry{'email_ldap1'} = $unblock_msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth1_ldap_mail};
				$newentry{'email_ldap2'} = $unblock_msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{auth2_ldap_mail};
				$newentry{'TOKEN_ID'} = $unblock_msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{token_id};
			}

			}
			
		}

		if($newentry{'WORKFLOW_TYPE'} eq config()->{openxpki}->{personalization})
		{
			if( ($newentry{'WORKFLOW_STATE'} ne 'SUCCESS') and ( $newentry{'WORKFLOW_STATE'} ne 'FAILURE' ) ){

			my $perso_msg =
				$c->send_receive_command_msg( 'get_workflow_info',
				{ 'WORKFLOW' => config()->{openxpki}->{personalization} , 'ID' => $newentry{'WORKFLOW_SERIAL'} } );

				if ( $self->is_error_response($perso_msg) ) {
			
					#$@ = "Error running get_workflow_info: " . Dumper($msg);  #fix me i18n
					#$responseData->{'error'} = "error";
					push(
							@{$errors},
							"I18N_OPENXPKI_CLIENT_SC_UTILITIES_ERROR_GETTING_WORKFLOW_INFO"
					);
					push( @{$errors}, $perso_msg );
				}else{
					#$responseData->{'perso_msg'} = $perso_msg;
					$newentry{'TOKEN_ID'} = $perso_msg->{PARAMS}->{WORKFLOW}->{CONTEXT}->{token_id};
				}

			}
			
		}

		if (! defined $last_update) {
			next ENTRY;
		}
		$newentry{'LAST_UPDATE_EPOCH'} = $last_update->epoch();

		push @activewf, \%newentry;
	}
}

	#foreach my $foundWf (sort keys $activeworkflows->{$key}){
# 
# 	my %wfinfo = (
# 	'wftype'          => $key,
# 	#'wf_num'     => scalar(@{$activeworkflows->{$key}}),
# 	'wf_ID'   => $activeworkflows->{$key}->[0]->{'WORKFLOW.WORKFLOW_SERIAL'} ,
# 	'wf_state'   => $activeworkflows->{$key}->[0]->{'WORKFLOW.WORKFLOW_STATE'} ,
# 	'wf_lastupdate'   => $activeworkflows->{$key}->[0]->{'WORKFLOW.WORKFLOW_LAST_UPDATE'} ,
# 	
# 	);
# 	my %wfinfo = (
# 	'wftype'          => $key,
# 	#'wf_num'     => scalar(@{$activeworkflows->{$key}}),
# 	'wf_ID'   => $foundWf->{'WORKFLOW.WORKFLOW_SERIAL'} ,
# 	'wf_state'   => $foundWf->{'WORKFLOW.WORKFLOW_STATE'} ,
# 	'wf_lastupdate'   => $foundWf->{'WORKFLOW.WORKFLOW_LAST_UPDATE'} ,
# 	
# 	);

# 	push( @activewf, \%wfinfo );
	#}

$responseData->{'creator_userID'} = 'set:'.$session->{'creator_userID'};
$responseData->{'cardOwner'} = $session->{'cardOwner'};	
$responseData->{'userWF'} = \@activewf;
$responseData->{'msg'} = $msg;
$responseData->{'outlook_displayname'} = config()->{outlook}->{displayname};
$responseData->{'outlook_b64'} = config()->{outlook}->{b64settings};
$responseData->{'outlook_issuerCN'} = config()->{outlook}->{issuerCN};


    $session->{"c"}            = $c;
    $responseData->{'errors'}  = $errors;
    $responseData->{'workflowtrace'}  = $workflowtrace;
    $session->{"responseData"} = $responseData;
		

#$session->{'creator'} = $msg->{PARAMS}->{SMARTCARD}->{assigned_to}->{workflow_creator} ;

    #data.msg.PARAMS.SMARTCARD.assigned_to.sn

#################Sent out json response#####################
    return $self->send_json_respond($responseData);

}

#Function encrypt_pin
#Description:Verify auth codes and fetch PUK
#Required Parameter via HTTPRequest:
#		cardID  						- cardSerialNumber
#		cardType 					- CardType String
#		userpin 						-userpin to encrypt
sub encrypt_pin {

    my ($self)       = @_;
    my $sessionID    = $self->pnotes->{a2c}{session_id};
    my $session      = $self->pnotes->{a2c}{session};
    my $responseData ;
    my $c            = 0;
    my $wf_type      = config()->{openxpki}->{pinunblock};
    my $u            = config()->{openxpki}->{user};
    my $p            = config()->{openxpki}->{role};
    my $wf_id;
    my $errors;
	 my $workflowtrace; 
    my $msg;
	 my $userpin;
	 my $newuserpin;

#########start session#######
    $self->start_session();
    $c            = $session->{"c"};
    $responseData = $session->{"responseData"};
    $errors				= $session->{"errors"};
 	 $workflowtrace 	=$session->{"workflowtrace"};
#################################PARAMETER#################################
	if(! defined $self->param("userpin") )
	{
		$responseData->{'error'} = "error";
		push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_UTILITIES_ENCRYPT_PIN_ERROR_MISSING_PARAMETER_USERPIN");
	}else{
		$userpin = $self->param('userpin');
	}
	if(! defined $self->param("newuserpin") )
	{
		$responseData->{'error'} = "error";
		push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_UTILITIES_ENCRYPT_PIN_ERROR_MISSING_PARAMETER_NEWUSERPIN");
	}else{
		$newuserpin = $self->param('newuserpin');
	}

#FIXME encrypt user PINs

   $responseData->{'serverPIN'} = $session->{'serverPIN'};
	$responseData->{'workflowtrace'} = $workflowtrace;

    if ( defined $responseData->{'error'} ) {
        $responseData->{'errors'} = $errors;
    }

    return $self->send_json_respond($responseData);


}

#echo JSON msg
#Required Parameter via HTTPRequest:
#Optional Parameter via HTTPRequest:

sub get_server_status {

    my ($self)    = @_;
    my $sessionID = $self->pnotes->{a2c}{session_id};
    my $session   = $self->pnotes->{a2c}{session};
    my $c            = 0;

###########################INIT##########################
    #$self->start_session();
    # $c = $session->{"c"};    #OpenXPKI socket connection
    my $responseData  = {};
    my $errors	= $session->{"errors"};  
    
    if(Log::Log4perl->initialized()) {
        # Yes, Log::Log4perl has already been initialized
        $responseData->{'log4perl init'} = "YES";
        
    } else {
   		 #Log::Log4perl->init_once("/var/applications/apache/pki/conf/log.conf");
        # No, not initialized yet ...
         $responseData->{'log4perl init'} = "NO";
    }
    
   $responseData->{'is initialized log4perl: '} = Log::Log4perl->initialized();
   
   my $log = Log::Log4perl->get_logger("openxpki.smartcard");

   $log->debug("Debug message from get server status ");
   $responseData->{'logs reached: '} =  $log->info("Info message from get server status");
	
	
	my $in = open(LOADAVG,"<", "/proc/loadavg");
	if(not defined($in)) {
		$responseData->{'error'} = "error";
		push(@{$errors},"I18N_OPENXPKI_CLIENT_WEBAPI_UTILITIES_ERROR_READ_LOADAVG");

	}
	
	my $pslist = `ps -fu openxpki | wc -l` ;
	chomp($pslist);
	
	$responseData->{'pslist'} = $pslist;
	$responseData->{'get_server_status'} = "read server infos";
	my @in = <LOADAVG>; 
	foreach my $line (@in)
	{
		my @values = split(/\s/ , $line);
		$responseData->{'loadavg'} = $line;
		$responseData->{'loadavg 1 min'} = $values[0];
		$responseData->{'loadavg 5 min'} = $values[1];
		$responseData->{'loadavg 15 min'} = $values[2];
	}
	$responseData->{'get_server_status'} = "Server OK";
	
	return $self->send_json_respond($responseData);

}

#Function server_log
#Description: Writes a messege to the server log
#Required Parameter via HTTPRequest:
#		cardID  					- cardSerialNumber
#		cardType 					- CardType String
#		message 					- log message
#		logtype 					- log level
sub server_log {
    my ($self)    = @_;
    my $sessionID = $self->pnotes->{a2c}{session_id};
    my $session   = $self->pnotes->{a2c}{session};
    my $c            = 0;
    my $loglevel = undef;

    if(Log::Log4perl->initialized()) {
        # Yes, Log::Log4perl has already boeen initialized
       #$responseData->{'log4perl init'} = "YES";
    } else {
   		Log::Log4perl->init_once("/var/applications/apache/pki/conf/log.conf");
        # No, not initialized yet ...
        # $responseData->{'log4perl init'} = "NO";
    }
     
    my $log = Log::Log4perl->get_logger("openxpki.smartcard");
	$log->info('msg:'.$self->param("message"). '  lvl:'.$self->param("log") );

	if($self->param("log") =~ /(info|debug|error|warn)/  ){
		
		$loglevel = $self->param("log");
		$log->$loglevel($self->param("message"));
	}else{
		$log->info($self->param("message"));
	}
	return;
}

1;

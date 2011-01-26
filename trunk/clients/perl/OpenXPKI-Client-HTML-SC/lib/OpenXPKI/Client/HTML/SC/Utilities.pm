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
    qw( get_card_status encrypt_pin)
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

###########################INIT##########################
    $self->start_session();
    $c = $session->{"c"};    #OpenXPKI socket connection
    my $responseData = $session->{"responseData"};
    $errors				= $session->{"errors"};
 	 my $workflowtrace 	=$session->{"workflowtrace"};
#########################################################

#########################Parse Input parameter###########
    # 	if(! defined $self->param("msg") )
    # 	{
    # 		$responseData->{'error'} = "error";
    # 		push(@errors,"No msg defined");
    # 	}else{
    # 		$responseData->{'usermsg'} =  $self->param("msg") ;
    # 	}

    if ( defined $self->{r}->headers_in()->get('ct-remote-user') && $self->{r}->headers_in()->get('ct-remote-user') ne '') {
        $AUTHUSER = $self->{r}->headers_in()->get('ct-remote-user');
    }

    #$responseData->{'cardID'} = $self->param("cardID");
    #	$responseData->{'cert0'} = $self->param("cert0");
    $responseData->{'Result'} = $self->param("Result");
CERTS:
    for ( my $i = 0; $i < 15; $i++ ) {
        last CERTS if !defined $self->param( "cert$i" );
        push( @certs, $self->param( "cert$i" ) );

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
        'WORKFLOW_TYPES' => ['I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK', 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V3' ],
        'SMARTCARDID'    => $session->{'id_cardID'},
    );
    if ( defined $AUTHUSER ) {
        $params{USERID} = $AUTHUSER;
    }

    $msg = $c->send_receive_command_msg( 'sc_analyze_smartcard', \%params, );

    if ( $self->is_error_response($msg) ) {
        $responseData->{'error'} = "error";
        push( @{$errors},
            "I18N_OPENXPKI_CLIENT_WEBAPI_SC_ERROR_GET_CARD_STATUS" );

	 }
	  

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

		if($newentry{'WORKFLOW_TYPE'} eq 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK')
		{
			if( ($newentry{'WORKFLOW_STATE'} ne 'SUCCESS') and ( $newentry{'WORKFLOW_STATE'} ne 'FAILURE' ) ){

			my $unblock_msg =
				$c->send_receive_command_msg( 'get_workflow_info',
				{ 'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PIN_UNBLOCK' , 'ID' => $newentry{'WORKFLOW_SERIAL'} } );
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

		if($newentry{'WORKFLOW_TYPE'} eq 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V3')
		{
			if( ($newentry{'WORKFLOW_STATE'} ne 'SUCCESS') and ( $newentry{'WORKFLOW_STATE'} ne 'FAILURE' ) ){

			my $perso_msg =
				$c->send_receive_command_msg( 'get_workflow_info',
				{ 'WORKFLOW' => 'I18N_OPENXPKI_WF_TYPE_SMARTCARD_PERSONALIZATION_V3' , 'ID' => $newentry{'WORKFLOW_SERIAL'} } );

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
$session->{'creator_userID'} = $msg->{PARAMS}->{SMARTCARD}->{assigned_to}->{workflow_creator};

$responseData->{'msg'} = $msg;

$responseData->{'creator_userID'} = $session->{'creator_userID'};
$responseData->{'userWF'} = \@activewf;
$responseData->{'msg'} = $msg;


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

1;

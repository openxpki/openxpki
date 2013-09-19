#
#
# SOAP server for mod_perl implementing the Revocation Interface for MailGW
# 

use strict;
use warnings;

package OpenXPKI::SOAP::Revoke;

use Config::Std;
use OpenXPKI::Client;
use OpenXPKI::Exception;
use Data::Dumper;
use OpenXPKI::Serialization::Simple;

use Apache2::ModSSL;

use Log::Log4perl qw(:easy);

my $configfile = $ENV{OPENXPKI_SOAP_CONFIG_FILE} || '/etc/openxpki/soap/default.conf';

my $config;
if (! read_config $configfile, $config) {
    die "Could not open SOAP interface config file $configfile";
}

my $log_config = $config->{global}->{log_config};
if (! $log_config) {
    die "Could not get Log4perl configuration file from config file";
}

my $facility = $config->{global}->{log_facility};
if (! $facility) {
    die "Could not get Log4perl logging facility from config file";
}

Log::Log4perl->init_once($log_config);

my $log = Log::Log4perl->get_logger($facility);

$log->info("SOAP interface NG initialized from config file $configfile");

my $socketfile = $config->{global}->{socket};
my $timeout = $config->{global}->{timeout} || 30;


# Adjust path to binary!
sub RevokeCertificate {

    my $class = shift;
    my $cert_identifier   = shift;
    my $reason = shift || 'unspecified';



    $log->debug("SOAP: Entered RevokeCertificate - ",
		"certificate: $cert_identifier, ",
		"reason: $reason");

    # check if the reason code is supported 
    if (
        $reason !~ m{ \A ( unspecified | keyCompromise | CACompromise | affiliationChanged | superseded | cessationOfOperation | certificateHold | removeFromCRL ) \z }xms )
    {
        $reason = 'unspecified';
    }

    my $client_ip   = $ENV{REMOTE_ADDR}; # dotted quad
    my $server_name = $ENV{SERVER_NAME}; # "dev-user-ca.tools.intranet.db.com"
    my $request_uri = $ENV{REQUEST_URI}; # "/soap/"

    my $package = __PACKAGE__;

    my $canonical_uri = $server_name . $request_uri;
    # remove trailing slashes
    $canonical_uri =~ s{ /+ \z }{}xms;
    

    $log->info("SOAP Revoke (uri: $canonical_uri, client ip=$client_ip, cert=$cert_identifier, reason=$reason");


    my $r = Apache2::RequestUtil->request();
    my $c = $r->connection;

    my $auth_dn;
    my $auth_cn;
    if ($c->is_https) {
	$log->debug("calling context is https");
	
	$auth_dn = $ENV{SSL_CLIENT_S_DN};
        $auth_cn = $ENV{SSL_CLIENT_S_DN_CN};
	if (defined $auth_dn) {
	    $log->info("SOAP Revoke authenticated client DN: $auth_dn");
	} else {
	    $log->info("SOAP Revoke unauthenticated");
	}
    } else {
	$log->debug("calling context is http");
    }

#    foreach my $key (keys %ENV) {
#	$log->debug("env $key -> " . $ENV{$key});
#    }

    my $pki_realm = $config->{$package}->{pki_realm};
    my $workflow_type = $config->{$package}->{workflow};
    my $auth_stack = $config->{$package}->{auth_stack};
    my $subject_match_regex = $config->{$package}->{subject_match_regex};

    if (! defined $pki_realm) {
	$log->error("SOAP CertificateRevoke: no pki_realm set for requested URI $canonical_uri");
	return SOAP::Data->new(name => 'responseCode', value => 1);
    }

    if (! defined $workflow_type) {
	$log->error("SOAP CertificateRevoke: no workflow_type set for requested URI $canonical_uri");
	return SOAP::Data->new(name => 'responseCode', value => 1);
    }

    # This should be moved into the workflow!
    my $flag_requester_authorized = 0;
    if (defined $auth_cn && defined $subject_match_regex) {
	$log->info("Checking authorization for requester $auth_cn");
	$log->debug("regex test: $subject_match_regex");

	my $re = qr($subject_match_regex);
	if ($auth_cn =~ m{$re}) {
	    $log->info("Requester $auth_cn is authorized to revoke certificates");
	    $flag_requester_authorized = 1;
	} else {
	    $log->warn("Requester authorization failed for $auth_cn");
	}
    }


    my $client;
    eval {
	$client = OpenXPKI::Client->new({
	    SOCKETFILE => $socketfile,
	    TIMEOUT    => $timeout,
	});
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
	$log->error("Could not establish OpenXPKI connection via socket file $socketfile: " . $exc->message);
	return SOAP::Data->new(name => 'responseCode', value => 1);
    }

    if (! $client) {
	$log->error("Could instantiate client object");
	return SOAP::Data->new(name => 'responseCode', value => 1);
    }

    if (! $client->is_connected()) {
	$log->error("Could not connect to server");
	return SOAP::Data->new(name => 'responseCode', value => 1);
    }

    if (! $client->init_session()) {
	$log->error("Could not initialize session");
	return SOAP::Data->new(name => 'responseCode', value => 1);
    }
    
    my $session_id = $client->get_session_id();
    #$log->debug("Session id: $session_id");

    my $reply = $client->send_receive_service_msg('PING');
    
    
  SERVICE_MESSAGE:
    while (1) {
 	my $status = $reply->{SERVICE_MSG};
	$log->debug("Status: $status");
	
 	if ($status eq 'GET_PKI_REALM') {
	    $log->debug("PKI Realm: $pki_realm");
 	    $reply = $client->send_receive_service_msg('GET_PKI_REALM',
 						       {
 							   PKI_REALM => $pki_realm,
 						       });
 	    next SERVICE_MESSAGE;
 	}
	
	if ($reply->{SERVICE_MSG} eq 'GET_AUTHENTICATION_STACK') {
	    if (defined $auth_stack) {
		$log->debug("Authentication stack: $auth_stack");
		$reply = $client->send_receive_service_msg('GET_AUTHENTICATION_STACK',
							   {
							       AUTHENTICATION_STACK => $auth_stack,
							   });
		next SERVICE_MESSAGE;
	    } else {
		$log->error("Authentication stack requested but not configured");
		return SOAP::Data->new(name => 'responseCode', value => 1);
	    }
	}
	
	if ($reply->{SERVICE_MSG} eq 'GET_PASSWD_LOGIN') {
	    $log->error("Username/password login requested (only anonymous login supported)");
	    return SOAP::Data->new(name => 'responseCode', value => 1);

#	    $reply = $client->send_receive_service_msg('GET_PASSWD_LOGIN',
#						       {
#							   LOGIN => $params{authuser},
#							   PASSWD => $params{authpass},
#						       });
#	    next SERVICE_MESSAGE;
	}

	if ($reply->{SERVICE_MSG} eq 'SERVICE_READY') {
	    last SERVICE_MESSAGE;
	}
	
	$log->error("Unhandled service message: '$status'");
	return SOAP::Data->new(name => 'responseCode', value => 1);
    }

    
    # logged in, now run required commands

    my $serializer = OpenXPKI::Serialization::Simple->new();

    my %wf_parameters =	
	(
	 cert_identifier  => $cert_identifier,
         reason_code      => $reason,	 
         crr_info => $serializer->serialize( { 
            requester_sn         => $auth_cn || '', # default to empty string (must not be undef)
            requester_authorized => $flag_requester_authorized,
            client_ip            => $client_ip,
         } ),
         flag_crr_auto_approval => $flag_requester_authorized,
         comment =>  $auth_cn . 'via soap',
         invalidity_time => time(),
	 );

    $log->debug("WF parameters: " . Dumper \%wf_parameters);

    $reply = $client->send_receive_service_msg('COMMAND',
					       {
						   COMMAND => 'create_workflow_instance',
						   PARAMS => {
						       WORKFLOW => $workflow_type,
						       PARAMS => \%wf_parameters,
						   }
					       });
    
    $log->debug("create_workflow_instance result: " . Dumper $reply);

    if (exists $reply->{SERVICE_MSG}) {
	if ($reply->{SERVICE_MSG} eq 'ERROR') {
	    $log->error("Could not create workflow instance");
	    return SOAP::Data->new(name => 'responseCode', value => 1);
	}

	if ($reply->{SERVICE_MSG} eq 'COMMAND') {
	    my $state = $reply->{PARAMS}->{WORKFLOW}->{STATE};
	    my $id    = $reply->{PARAMS}->{WORKFLOW}->{ID};
	    $log->info("Queued revocation request creation workflow (Workflow id: $id, state: $state)");
	    return SOAP::Data->new(name => 'responseCode', value => 0);
	}
    }
    
    # general error
    $log->warn("Revocation request was not processed properly");
    my $res = Dumper $reply;
    $log->debug("reply dump: " . $res);
    return SOAP::Data->new(name => 'responseCode', value => 1);
}

sub true {
    my $self = shift;
    warn "Entered 'true'";
    return 1;
}

sub false {
    my $self = shift;
    return 0;
}

sub echo {
    my $self = shift;
    return shift @_;
}

1;

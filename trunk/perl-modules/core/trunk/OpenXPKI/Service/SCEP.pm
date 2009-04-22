## OpenXPKI::Service::SCEP
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project

package OpenXPKI::Service::SCEP;

use base qw( OpenXPKI::Service );

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

## used modules

use OpenXPKI::i18n qw(set_language);
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server;
use OpenXPKI::Server::Session::Mock;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Service::SCEP::Command;
use Data::Dumper;

sub init {
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "start"

    # init (mock) session
    $self->__init_session();
    
    # get realm from client and save in session
    my $realm = $self->__init_pki_realm();
    CTX('session')->set_pki_realm($realm);
    my $profile = $self->__init_profile();
    CTX('session')->set_profile($profile);
    my $server = $self->__init_server();
    CTX('session')->set_server($server);
    my $encryption_alg = $self->__init_encryption_alg();
    CTX('session')->set_enc_alg($encryption_alg);
    CTX('session')->set_user($server);

    return 1;
}

sub __init_profile :PRIVATE {
    ##! 4: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $realm = CTX('session')->get_pki_realm();
    
    # check endentity profile list
    my @list = sort keys %{CTX('pki_realm')->{$realm}->{endentity}->{id}};
    ##! 16: Dumper(@list)
    if (scalar @list < 1) {
        ##! 4: "no endentity profiles configured"
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_NO_ENDENTITY_PROFILES_CONFIGURED",
        );
    }

    ##! 2: "build hash with names"
    my %profiles =();
    foreach my $profile (@list) {
        $profiles{$profile}->{NAME}        = $profile;
    }

    my $message = $self->collect();
    ##! 16: "message collected: " . Dumper($message)
    my $requested_profile;
    if ($message =~ /^SELECT_PROFILE (.*)/) {
        $requested_profile = $1;
        ##! 16: "requested profile: $requested_profile"
    }
    else {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_NO_SELECT_PROFILE_RECEIVED",
        );
        # this is an uncaught exception
    }

    if (defined $profiles{$requested_profile}->{NAME}) { # the profile is valid
        $self->talk('OK');
        return $requested_profile;
    }
    else { # the requested profile was not found in the server configuration
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_INVALID_PROFILE_REQUESTED",
            params  => {REQUESTED_PROFILE => $requested_profile},
        );
    }
}

sub __init_server : PRIVATE {
    ##! 4: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $realm = CTX('session')->get_pki_realm();
    
    my $message = $self->collect();
    ##! 16: "message collected: " . Dumper($message)
    my $requested_server;
    if ($message =~ /^SELECT_SERVER (.*)/) {
        $requested_server = $1;
        ##! 16: "requested server: $requested_server"
    }
    else {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_NO_SELECT_SERVER_RECEIVED",
        );
        # this is an uncaught exception
    }
    if (exists CTX('pki_realm')->{$realm}->{scep}->{id}->{$requested_server}) {
        # the server is valid
        $self->talk('OK');
        return $requested_server;
    }
    else { # the requested profile was not found in the server configuration
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_INVALID_SERVER_REQUESTED",
            params  => {REQUESTED_SERVER => $requested_server},
        );
    }
}

sub __init_encryption_alg : PRIVATE {
    ##! 4: 'start'
    my $self    = shift;
    my $ident   = ident $self;
    my $arg_ref = shift;

    my $realm = CTX('session')->get_pki_realm();
    
    my $message = $self->collect();
    ##! 16: "message collected: " . Dumper($message)
    my $requested_encryption_alg;
    if ($message =~ /^SELECT_ENCRYPTION_ALGORITHM (.*)/) {
        $requested_encryption_alg = $1;
        ##! 16: "requested encryption_alg: $requested_encryption_alg"
    }
    else {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_NO_SELECT_ENCRYPTION_ALGORITHM_RECEIVED",
        );
        # this is an uncaught exception
    }
    if ($requested_encryption_alg eq 'DES' ||
        $requested_encryption_alg eq '3DES') {
        # the encryption_alg is valid
        $self->talk('OK');
        return $requested_encryption_alg;
    }
    else { # the requested encryption algorithm is invalid
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_INVALID_ALGORITHM_REQUESTED",
            params  => {REQUESTED_ALGORITHM => $requested_encryption_alg},
        );
    }
}


sub __init_session : PRIVATE {
    my $self    = shift;
    my $ident   = ident $self;
    my $arg     = shift;

    my $session = undef;
    # use a mock session to save the PKI realm in
    $session = OpenXPKI::Server::Session::Mock->new(); 
    OpenXPKI::Server::Context::setcontext({'session' => $session});
}

sub __init_pki_realm :PRIVATE
{
    my $self    = shift;
    my $ident   = ident $self;
    my $arg     = shift;

    ##! 1: "start"

    ##! 2: "check if there is more than one PKI realm"
    my @list = sort keys %{CTX('pki_realm')};
    if (scalar @list < 1)
    {
        ##! 4: "no PKI realm configured"
        OpenXPKI::Exception->throw
        (
            message => "I18N_OPENXPKI_SERVICE_SCEP_GET_PKI_REALM_NO_REALM_CONFIGURED",
        );
    }

    ##! 2: "build hash with names"
    my %realms =();
    foreach my $realm (@list)
    {
        $realms{$realm}->{NAME}        = $realm;
    }

    my $message = $self->collect();
    ##! 16: "message collected: $message"
    my $requested_realm;
    if ($message =~ /^SELECT_PKI_REALM (.*)/) {
        $requested_realm = $1;
        ##! 16: "requested realm: $requested_realm"
    }
    else {
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_NO_SELECT_PKI_REALM_RECEIVED",
        );
    }

    if (defined $realms{$requested_realm}->{NAME}) { # the realm is valid
        $self->talk('OK');
        return $requested_realm;
    }
    else { # the requested realm was not found in the server configuration
        $self->talk('NOTFOUND');
        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVICE_SCEP_INVALID_REALM_REQUESTED",
            params  => {REQUESTED_REALM => $requested_realm},
        );
    }
}

sub run
{
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

  MESSAGE:
    while (1)
    {
	my $data;
	eval {
	    $data = $self->collect();
            ##! 16: "data collected: $data"
	};
	if (my $exc = OpenXPKI::Exception->caught()) {
	    if ($exc->message() =~ m{I18N_OPENXPKI_TRANSPORT.*CLOSED_CONNECTION}xms) {
		# client closed socket
		last MESSAGE;
	    } else {
		$exc->rethrow();
	    }
	} elsif ($EVAL_ERROR) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVICE_SCEP_RUN_READ_EXCEPTION",
		params  => {
		    EVAL_ERROR => $EVAL_ERROR,
		});
	}

	last MESSAGE unless defined $data;

	my $service_msg = $data->{SERVICE_MSG};
	if (! defined $service_msg) {
	    $self->talk(
	        $self->__get_error(
		    {
			ERROR => 'I18N_OPENXPKI_SERVICE_SCEP_RUN_MISSING_SERVICE_MESSAGE',
		    }));
	    
	    next MESSAGE;
	}			

	##! 4: "$service_msg"

        ##! 4: "check for logout"
        if ($service_msg eq 'LOGOUT')
        {
            ##! 8: "logout received - killing session and connection"
	    CTX('log')->log(
		MESSAGE  => 'Terminating session',
		PRIORITY => 'info',
		FACILITY => 'system',
		);
            exit 0;
        }

	if ($service_msg eq 'COMMAND') {
	    if (exists $data->{PARAMS}->{COMMAND}) {
                my $received_command = $data->{PARAMS}->{COMMAND};
                my $received_params  = $data->{PARAMS}->{PARAMS};
                ##! 16: "COMMAND: $received_command  PARAMS: $received_params"

		my $command;
		eval {
		    $command = OpenXPKI::Service::SCEP::Command->new(
			{
			    COMMAND => $received_command,
			    PARAMS  => $received_params,
			});
		};
		if (my $exc = OpenXPKI::Exception->caught()) {
		    if ($exc->message() =~ m{
                            I18N_OPENXPKI_SERVICE_SCEP_COMMAND_INVALID_COMMAND
                        }xms) {
			##! 16: "Invalid command $data->{PARAMS}->{COMMAND}"
			# fall-through intended
		    } else {
			$exc->rethrow();
		    }
		} elsif ($EVAL_ERROR) {
		    OpenXPKI::Exception->throw (
			message => "I18N_OPENXPKI_SERVICE_SCEP_RUN_COULD_NOT_INSTANTIATE_COMMAND",
			params  => {
			    EVAL_ERROR => $EVAL_ERROR,
			});
		}

		if (defined $command) {
		    my $result;
		    eval {
			$result = $command->execute();
		    };
		    if ($EVAL_ERROR) {
			##! 14: "Exception caught during command execution"
                        ##! 14: "$EVAL_ERROR"
			$self->talk(
			    $self->__get_error(
			        {
				    ERROR => 'I18N_OPENXPKI_SERVICE_SCEP_RUN_COMMAND_EXECUTION_FAILED',
				    EXCEPTION => $EVAL_ERROR,
				}));
			
			next MESSAGE;
		    }
		    CTX('log')->log(
			MESSAGE  => "Executed SCEP command '$received_command'",
			PRIORITY => 'debug',
			FACILITY => 'system',
			);


		    # sanity checks on command reply
		    if (! defined $result || ref $result ne 'HASH') {
			$self->talk(
			    $self->__get_error(
			        {
				    ERROR => "I18N_OPENXPKI_SERVICE_SCEP_RUN_ILLEGAL_COMMAND_RETURN_VALUE",
				}));

			next MESSAGE;
		    }

		    $self->talk($result);

		    next MESSAGE;
		}
	    }

	    $self->talk(
	        $self->__get_error(
		    {
			ERROR => "I18N_OPENXPKI_SERVICE_SCEP_RUN_UNRECOGNIZED_COMMAND",
		    }));

	    next MESSAGE;
	}

	$self->talk(
	    $self->__get_error(
	        {
		    ERROR => "I18N_OPENXPKI_SERVICE_SCEP_RUN_UNRECOGNIZED_SERVICE_MESSAGE",
		}));
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Service::SCEP - SCEP service implementation

=head1 Description

This is the Service implementation which is used by SCEP clients.
The protocol is simpler than in the Default implementation, as it
does not use user authentication and session handling.

=head1 Protocol Definition

The protocol starts with the client sending a "SELECT_PKI_REALM" message
indicating which PKI realm the clients wants to use. Depending on whether
this realm is available at the server or not, the server responds with
either "OK" or "NOTFOUND".


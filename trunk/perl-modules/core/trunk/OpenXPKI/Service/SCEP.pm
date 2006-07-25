## OpenXPKI::Service::SCEP
##
## Written 2006 by Alexander Klink for the OpenXPKI project
## (C) Copyright 2006 by The OpenXPKI Project
## $Revision: 389 $

package OpenXPKI::Service::SCEP;

use base qw( OpenXPKI::Service );

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

## used modules

use OpenXPKI::i18n qw(set_language);
use OpenXPKI::Debug 'OpenXPKI::Service::SCEP';
use OpenXPKI::Exception;
use OpenXPKI::Server;
use OpenXPKI::Server::Session::Mock;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Service::SCEP::Command;

sub init
{
    my $self  = shift;
    my $ident = ident $self;
    my $args  = shift;

    ##! 1: "start"

    # init (mock) session
    $self->__init_session();
    
    # get realm from client and save in session
    my $realm = $self->__init_pki_realm();
    CTX('session')->set_pki_realm($realm);


    return 1;
}

sub __init_session :PRIVATE
{
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
        OpenXPKI::Exception->throw({
            message => "I18N_OPENXPKI_SERVICE_SCEP_NO_SELECT_PKI_REALM_RECEIVED",
        });
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
		# FIXME: return error instead of rethrowing
		$exc->rethrow();
	    }
	} elsif ($EVAL_ERROR) {
	    if (ref $EVAL_ERROR) {
		$EVAL_ERROR->rethrow();
	    } else {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVICE_SCEP_RUN_READ_EXCEPTION",
		    params  => {EVAL_ERROR => $EVAL_ERROR});
	    }
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
		    if (ref $EVAL_ERROR) {
			$EVAL_ERROR->rethrow();
		    } else {
			OpenXPKI::Exception->throw (
			    message => "I18N_OPENXPKI_SERVICE_SCEP_RUN_COULD_NOT_INSTANTIATE_COMMAND",
			    params  => {
				EVAL_ERROR => $EVAL_ERROR,
			    });
		    }
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

		    # sanity checks on command reply
		    if (! defined $result || ref $result ne 'HASH') {
			$self->talk(
			    $self->__get_error(
			        {
				    ERROR => "I18N_OPENXPKI_SERVICE_SCEP_RUN_ILLEGAL_COMMAND_RETURN_VALUE",
				}));

			next MESSAGE;
		    }

		    # FIXME: translate messages
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


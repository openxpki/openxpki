## OpenXPKI::Service.pm 
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision: 269 $

package OpenXPKI::Service;

use strict;
use warnings;
use utf8;
use English;

use Class::Std;

## used modules

use OpenXPKI::Debug 'OpenXPKI::Service';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;

my %transport              : ATTR( :init_arg<TRANSPORT> );
my %serialization          : ATTR( :init_arg<SERIALIZATION> );

my %communication_state    : ATTR( :get<communication_state> :set<communication_state> );
my %api                    : ATTR( :get<API> );

my %read_timeout           : ATTR( :set<timeout> );


sub BUILD {
    my ($self, $ident, $arg_ref) = @_;

    $api{$ident} = OpenXPKI::Server::API->new();
}


# send message to client
sub talk {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    my $communication_state = $self->get_communication_state();
    # this may be undefined in the first invocation, accept it this way
    if (! defined $communication_state || ($communication_state eq 'can_send')) {
	my $rc = $transport{$ident}->write(
	    $serialization{$ident}->serialize($arg)
	    );
	$self->set_communication_state('can_receive');
	return $rc;
    } else {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_SERVICE_TALK_INCORRECT_COMMUNICATION_STATE",
	    params => {
		status => $self->get_communication_state(),
	    },
	    );
    }
}



# get server response
sub collect {
    my $self  = shift;
    my $ident = ident $self;

    my $communication_state = $self->get_communication_state();
    # this may be undefined in the first invocation, accept it this way
    if (defined $communication_state && ($communication_state ne 'can_receive')) {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_SERVICE_COLLECT_INCORRECT_COMMUNICATION_STATE",
	    params => {
		status => $self->get_communication_state(),
	    },
	    );
    }

    my $result;
    eval {
	local $SIG{ALRM} = sub { die "alarm\n" };
	if (defined $read_timeout{$ident}) {
	    alarm $read_timeout{$ident};
	}

 	$result = $serialization{$ident}->deserialize(
 	    $transport{$ident}->read()
 	    );
 	alarm 0;
    };
    if ($EVAL_ERROR) {
 	if ($EVAL_ERROR eq "alarm\n") {
	    OpenXPKI::Exception->throw(
	        message => "I18N_OPENXPKI_SERVICE_COLLECT_TIMEOUT",
	    );
 	} else {
	    # FIXME
	    die $EVAL_ERROR;
	}
    }
    $self->set_communication_state('can_send');
    return $result;
}


sub __get_error {
    my $self  = shift;
    my $ident = ident $self;
    my $arg   = shift;
    
    if (! exists $arg->{ERROR} || (ref $arg->{ERROR} ne '')) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_ERROR_INVALID_PARAMETERS",
	    params => {
		PARAMETER => 'ERROR',
	    }
	    );
    }

    my $result = {
	ERROR => $arg->{ERROR},
    };

    if (exists $arg->{PARAMS}) {
	if (ref $arg->{PARAMS} ne 'HASH') {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVICE_DEFAULT_GET_ERROR_INVALID_PARAMETERS",
		params => {
		    PARAMETER => 'PARAMS',
		}
		);
	}
	$result->{PARAMS} = $arg->{PARAMS};
    }
    if (exists $arg->{EXCEPTION}) {
	$result->{EXCEPTION} = $arg->{EXCEPTION};
	$result->{EXCEPTION_AS_STRING} = OpenXPKI::Server::exception_as_string($arg->{EXCEPTION});
    }
    
    $result->{ERROR_MESSAGE} = OpenXPKI::i18nGettext($result->{ERROR}, 
						     %{$result->{PARAMS}});
    
    return $result;
}



1;

=head1 Description

Base class for service implementations. The protocol definition itself
is left to the derived classes.

=head2 Methods

=head3 talk

Expects hash reference to send to the client. Serialized data structure
and sends message via the transport layer.

=head3 collect

Reads message from the client, deserializes the input and returns
the corresponding data structure.

=head3 set_timout

Sets read timeout (seconds) for the collect() call. If no message is
read within the specified timout collect() terminates with an exception.
Default is undef which means no timeout (wait forever).

=head3 get_API

Gets OpenXPKI::Server::API object.


=head3 __get_error

Expects named arguments 'ERROR' (required) and 'PARAMS' (optional).
ERROR must be a scalar indicating an I18N message, PARAMS are optional
variables (just like params in OpenXPKI Exceptions).

Returns a hash reference containing the original named parameters ERROR and
PARAMS (if specified) the corresponding i18n translation (in ERROR_MESSAGE).

Throws an exception if named argument ERROR is not a scalar.


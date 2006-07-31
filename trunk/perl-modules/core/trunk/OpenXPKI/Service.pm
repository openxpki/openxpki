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

use Data::Dumper;
## used modules

use OpenXPKI::Debug 'OpenXPKI::Service';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;
use OpenXPKI::i18n qw( i18nGettext );

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

    ##! 128: Dumper $arg
    
    ##! 2: "setup errors array"
    my @errors = ();
    if ($arg->{ERRORS})
    {
        push @errors, @{$arg->{ERRORS}};
    }
    if (exists $arg->{ERROR})
    {
        push @errors, $arg->{ERROR};
    }
    if (exists $arg->{EXCEPTION})
    {
        push @errors, $arg->{EXCEPTION};
    }
    if (exists $arg->{EXCEPTIONS})
    {
        push @errors, @{$arg->{EXCEPTIONS}};
    }

    ##! 2: "normalize error list"
    my @list = ();
    foreach my $error (@errors)
    {
        if (not ref $error)
        {
            ## this is an error
            push @list, {LABEL => $error};
        }
        else
        {
            ## this is an exception
            my %hash = (LABEL => $error->message());
            $hash{PARAMS} = $error->params()
                if (defined $error->params());
            $hash{CHILDREN} = [ $self->__get_error ({EXCEPTIONS => $error->children()}) ]
                if (defined $error->children());
            push @list, \%hash;
        }
    }

    ##! 1: "return serialized error list"
    return @list;
}

1;

=head1 Name

OpenXPKI::Service - base class for services.

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

Expects the following named parameters:

=over

=item * ERROR

a single error string or an array reference (please see the array
description below)

=item * ERRORS

a list of error like described for the ERROR parameter

=item * EXCEPTION

a single OpenXPKI::Exception

=item * EXCEPTIONS

an array of OpenXPKI::Exception

=back


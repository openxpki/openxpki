## OpenXPKI::Service::Default::Command
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
## $Revision: 235 $
##

use strict;
use warnings;

package OpenXPKI::Service::Default::Command;
use English;

use Class::Std;

use OpenXPKI::Debug 'OpenXPKI::Service::Default::Command';
use OpenXPKI::Exception;
use OpenXPKI::Server::API;

my %command        : ATTR;
my %command_params : ATTR;

my %command_impl   : ATTR;

my %allowed_command = map { $_ => 1 } qw(
    nop
    list_workflow_instances
    list_workflow_titles
);

sub BUILD {
    my ($self, $ident, $arg_ref) = @_;

    $command{$ident}        = $arg_ref->{COMMAND};
    $command_params{$ident} = $arg_ref->{PARAMS};
}

sub START {
    my ($self, $ident, $arg_ref) = @_;

    # only in Command.pm base class: get implementation
    if (ref $self eq 'OpenXPKI::Service::Default::Command') {
	$self->attach_impl($arg_ref);
    }
}



sub attach_impl : PRIVATE {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    ##! 4: "attaching implementation"

    # command name
    my $cmd = $command{$ident};

    my $base = 'OpenXPKI::Service::Default::Command';

    if (defined $cmd && $allowed_command{$cmd}) {
	# command was white-listed and explicitly allowed
	
	my $class = $base . '::' . $cmd;
	##! 8: "loading class $class"
	eval "use $class;";
	if ($EVAL_ERROR) {
	    OpenXPKI::Exception->throw(
	        message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_IMPL_LOAD_FAILED",
	        params  => {EVAL_ERROR => $EVAL_ERROR,
			    MODULE     => $class});
	}
	
	##! 8: "instantiating class $class"
	$command_impl{$ident} = eval "$class->new()";
	if ($EVAL_ERROR) {
	    OpenXPKI::Exception->throw(
	        message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_IMPL_INSTANTIATE_FAILED",
	        params  => {EVAL_ERROR => $EVAL_ERROR,
			    MODULE     => $class});
	}
	
    } else {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_SERVICE_DEFAULT_COMMAND_INVALID_COMMAND",
	    );
    } 
    
    return 1;
}



sub execute {
    my $self  = shift;
    my $arg   = shift;
    my $ident = ident $self;

    ##! 4: "execute: $command{$ident}"
    ##! 16: "ref child: " . ref $command_impl{$ident}
    if (ref $command_impl{$ident}
	eq 'OpenXPKI::Service::Default::Command::' . $command{$ident}) {
	##! 16: "implementation is present, delegating"
	return $command_impl{$ident}->execute(
	    {
		PARAMS => $command_params{$ident},
	    });
    }
    ##! 4: "FIXME: throw exception?"
    return {
	ERROR => "COMMAND EXECUTION METHOD NOT IMPLEMENTED",
    };
}

1;

__END__

=head1 Description

Default service command base class. Handles command execution to
distinct command implementations.

=head1 Functions

=head2 BUILD
=head2 START - new()

This class derives from Class::Std. Please read the corresponding 
documentation concerning BUILD, START construction methods and other
class-specific internals.

The new() constructor creates a new command object that is capable 
of executing the referenced interface command.
Expects the following named parameters:
  COMMAND => name of the command to execute
  PARAMS  => hash reference containing the command attributes

The constructor makes sure that only explicitly allowed commands are
accepted and throws an exception otherwise. If the constructor returns
without error (exception), the command was accepted as valid and the 
passed parameters have been stored internally to be processed later 
by the execute() method.

=head2 execute

Executes the specified command implementation. Returns a data structure 
that can be serialized and directly returned to the client.


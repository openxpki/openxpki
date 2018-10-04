## OpenXPKI::Service::Default::Command
##
## Written 2006 by Martin Bartosch for the OpenXPKI project
## (C) Copyright 2005-2006 by The OpenXPKI Project
##

use strict;
use warnings;

package OpenXPKI::Service::Default::Command;
use English;
use Data::Dumper;

use Class::Std;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::API;

my %command        : ATTR;
my %command_params : ATTR;

my %api            : ATTR( :get<API> );

sub BUILD {
    my ($self, $ident, $arg_ref) = @_;

    $command{$ident}        = $arg_ref->{COMMAND};
    $command_params{$ident} = $arg_ref->{PARAMS};
    $api{$ident}            = OpenXPKI::Server::API->new({
                                EXTERNAL => 1,
    });
}

sub START {
    my ($self, $ident, $arg_ref) = @_;

}

sub execute {
    my $self  = shift;
    my $ident = ident $self;

    ##! 4: "execute: $command{$ident}"
    my $method = $command{$ident};
    ##! 8: "automatic API mapping for $method"

    my $used_api = $self->get_API();
    ##! 8: "call function at API"
    ##! 16: 'command_params{ident}: ' . Dumper $command_params{$ident}

    return {
        SERVICE_MSG => 'COMMAND',
        COMMAND => $method,
        PARAMS  => $used_api->$method($command_params{$ident}),
    }
}


1;
__END__

=head1 Name

OpenXPKI::Service::Default::Command

=head1 Description

Default service command base class. Handles command execution to
distinct command implementations.

=head1 Functions

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

The execute() method looks up the command in the central API and calls
the given subroutine with the parameters given to new.

=head2 execute

Executes the specified command implementation. Returns a data structure
that can be serialized and directly returned to the client.



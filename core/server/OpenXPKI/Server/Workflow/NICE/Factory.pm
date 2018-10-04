## OpenXPKI::Server::Workflow::NICE.pm
## Factory for NICE Backends
##
## Written 2011 by Oliver Welter <openxpki@oliwel.de>
## for the OpenXPKI project
## (C) Copyright 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::NICE::Factory;

use strict;
use warnings;
use English;

use Data::Dumper;

use OpenXPKI::Debug;
use OpenXPKI::Exception;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Workflow::NICE;

sub getHandler {

    shift; # Pull of class
    my $activity = shift;

    my $backend = CTX('config')->get('nice.backend');

    $backend = 'Local' unless( $backend );

    my $BackendClass = 'OpenXPKI::Server::Workflow::NICE::'.$backend;
    ##! 16: 'Load Backend: '.$backend

    use OpenXPKI::Server::Workflow::NICE::Local;

    if(!eval("require $BackendClass")){
        OpenXPKI::Exception->throw(
              message => "I18N_OPENXPKI_SERVER_NICE_NO_SUCH_BACKEND",
              params => {
                  backend => $backend,
                  class =>  $BackendClass,
                  error => $EVAL_ERROR
              }
        );
    }
    CTX('log')->application()->debug("NICE backend $backend loaded, execute $activity->name");

    return $BackendClass->new( $activity );

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::NICE::Factory

=head1 Description

Provides a factory interface to get a subclass of
OpenXPKI::Server::Workflow::NICE to access the configured backend.

=head1 Functions

=head2 getHandler

The static factory handler, expects the workflow activity object as parameter
e.g. OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self )
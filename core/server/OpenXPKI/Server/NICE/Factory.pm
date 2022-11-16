package OpenXPKI::Server::NICE::Factory;

use strict;
use warnings;
use English;


use OpenXPKI::Debug;
use OpenXPKI::Exception;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::NICE;

sub getHandler {

    shift; # Pull of class
    my $activity = shift;

    my $backend = CTX('config')->get('nice.backend');

    $backend = 'Local' unless( $backend );

    my $BackendClass = 'OpenXPKI::Server::NICE::'.$backend;
    ##! 16: 'Load Backend: '.$backend

    if(!eval("require $BackendClass")){
        OpenXPKI::Exception->throw(
              message => "I18N_OPENXPKI_UI_NICE_NO_SUCH_BACKEND",
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

OpenXPKI::Server::NICE::Factory

=head1 Description

Provides a factory interface to get a subclass of
OpenXPKI::Server::NICE to access the configured backend.

=head1 Functions

=head2 getHandler

The static factory handler, expects the workflow activity object as parameter
e.g. OpenXPKI::Server::NICE::Factory->getHandler( $self )

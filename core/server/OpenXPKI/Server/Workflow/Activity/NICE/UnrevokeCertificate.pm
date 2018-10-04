# OpenXPKI::Server::Workflow::Activity::NICE::UnrevokeCertificate
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::UnrevokeCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use OpenXPKI::Server::Workflow::NICE::Factory;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;

    ##! 32: 'context: ' . Dumper(  $workflow->context() )

    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );

     CTX('log')->application()->info("start cert unrevoke for cert ".$self->_get_context_param( 'cert_identifier' ).", workflow " . $workflow->id);


    # We do not need an attribute map here
    $nice_backend->unrevokeCertificate( $self->_get_context_param( 'cert_identifier' )  );

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::unrevokeCertificate;

=head1 Description

Activity to unrevoke a certificate using the configured NICE backend.

See OpenXPKI::Server::Workflow::NICE::unrevokeCertificate for details

=head1 Parameters

=head2 Input

=over

=item cert_identifier - identifier of the certificate

=back

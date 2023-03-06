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

use OpenXPKI::Server::NICE::Factory;


sub execute {
    my $self     = shift;
    my $workflow = shift;

    ##! 32: 'context: ' . Dumper(  $workflow->context() )

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );
    my $cert_identifier = $self->param('cert_identifier') || $context->param('cert_identifier');

    CTX('log')->application()->info("start cert unrevoke for cert $cert_identifier, workflow " . $workflow->id);

    my $param = $self->param();
    delete $param->{'cert_identifier'};
    $nice_backend->unrevokeCertificate( $cert_identifier, $param );

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::UnrevokeCertificate

=head1 Description

Unrevoke a certificate using the configured NICE backend.

See L<OpenXPKI::Server::NICE/unrevokeCertificate> for details

=head1 Parameters

=head2 Input

=over

=item cert_identifier - identifier of the certificate

=back

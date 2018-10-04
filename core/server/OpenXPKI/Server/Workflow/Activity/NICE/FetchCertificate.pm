# OpenXPKI::Server::Workflow::Activity::NICE::FetchCertificate
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::FetchCertificate;

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
    my $context = $workflow->context();

    ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );

    my $set_context = $nice_backend->fetchCertificate();

    ##! 64: 'Setting Context ' . Dumper $set_context
    #while (my ($key, $value) = each(%$set_context)) {
    foreach my $key (keys %{$set_context} ) {
        my $value = $set_context->{$key};
        $context->param( $key, $value );
    }

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::IssueCertificate;

=head1 Description

Fetch a certificate for a pending certificate signing request.

See OpenXPKI::Server::Workflow::NICE::fetchCertificate for details

=head1 Parameters

=head2 Output

=over

=item cert_identifier - the identifier of the issued certificate

=back

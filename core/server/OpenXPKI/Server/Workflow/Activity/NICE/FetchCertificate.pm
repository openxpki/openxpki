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

use OpenXPKI::Server::NICE::Factory;


sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $context = $workflow->context();

    ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    my $param = $self->param();

    my $set_context = $nice_backend->fetchCertificate($param);

    if (!$set_context->{cert_identifier} && $self->get_max_allowed_retries()) {
        $self->pause('I18N_OPENXPKI_UI_NICE_ISSUANCE_PENDING');
    }

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

OpenXPKI::Server::Workflow::Activity::NICE::FetchCertificate;

=head1 Description

Fetch a certificate for a pending certificate signing request.

If no cert_identifer is found in the response and retry_count is set,
the activity will go into pause.

See OpenXPKI::Server::NICE::fetchCertificate for details

=head1 Parameters

=head2 Input

All input parameters to the method are passed to the backend.

=head2 Output

=over

=item cert_identifier - the identifier of the issued certificate

=back

All other parameters from the response are also added to the context.
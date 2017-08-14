# OpenXPKI::Server::Workflow::Activity::NICE::RenewCertificate
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::RenewCertificate;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Database::Legacy;

use OpenXPKI::Server::Workflow::NICE::Factory;

use Data::Dumper;

sub execute {
    my ($self, $workflow) = @_;
    my $context = $workflow->context();
        ##! 32: 'context: ' . Dumper( $context )

    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );

    # Load the CSR indicated by the context parameter from the database
    my $csr_serial = $context->param( 'csr_serial' );

    ##! 64: 'load csr from db: ' . $csr_serial
    my $csr = CTX('dbi')->select_one(
        from => 'csr',
        columns => [ '*' ],
        where => { req_key => $csr_serial },
    );

    ##! 64: 'csr: ' . Dumper %csr
    if (! defined $csr) {
       OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_NICE_CSR_NOT_FOUND_IN_DATABASE',
           params => { csr_serial => $csr_serial }
       );
    }

    if ($csr->{format} ne 'pkcs10') {
       OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_NICE_CSR_WRONG_TYPE',
           params => { EXPECTED => 'pkcs10', TYPE => $csr->{format} },
        );
    }

    CTX('log')->application()->info("start cert renewal for csr_serial $csr_serial, workflow " . $workflow->id);


    my $set_context = $nice_backend->renewCertificate(
        OpenXPKI::Server::Database::Legacy->csr_to_legacy($csr),
        $context->param( 'org_cert_identifier' ),
    );

    ##! 64: 'Setting Context ' . Dumper $set_context
    for my $key (keys %{$set_context} ) {
        my $value = $set_context->{$key};
        $context->param( $key, $value );
    }
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::RenewCertificate;

=head1 Description

Loads the certificate signing request referenced by the csr_serial context
parameter and hands it to the configured NICE backend, together with the
identifier of the originating certificate (the one to be renewed) from the
context.

See OpenXPKI::Server::Workflow::NICE::issueCertificate for details

=head1 Parameters

=head2 Input

=over

=item csr_serial - the serial number of the certificate signing request

=item org_cert_identifier - identifier of the originating certificate

=back

=head2 Output

=over

=item cert_identifier - the identifier of the issued certificate or I<pending>

=back

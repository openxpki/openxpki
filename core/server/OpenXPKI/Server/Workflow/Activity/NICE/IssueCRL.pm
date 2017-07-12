# OpenXPKI::Server::Workflow::Activity::NICE::IssueCRL
# Written by Oliver Welter for the OpenXPKI Project 2011
# Copyright (c) 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::NICE::IssueCRL;

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

    ##! 32: 'context: ' . Dumper( $context  )

    my $nice_backend = OpenXPKI::Server::Workflow::NICE::Factory->getHandler( $self );

    my $ca_alias = $context->param( 'ca_alias' );

    if (!$ca_alias) {
       OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_NICE_CRLISSUANCE_NO_CA_ID",
        );
    }

    CTX('log')->application()->info("start crl issue for ca $ca_alias, workflow " . $workflow->id);


    my $set_context = $nice_backend->issueCRL( $ca_alias );

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

OpenXPKI::Server::Workflow::Activity::NICE::IssueCRL;

=head1 Description

Activity to initate CRL issuance using the configured NICE backend.

See OpenXPKI::Server::Workflow::NICE::issueCRL for details

=head1 Parameters

=head2 Input

=over

=item crl_validity - DateTime Spec for CRL Validity, optional

=item delta_crl (bool) - Issue a delta CRL (Delta CRL Support is untestet!)

=back

=head2 Output

=over

=item crl_serial - the serial number of the issued crl or I<pending>

=back

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

use OpenXPKI::Server::NICE::Factory;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $context = $workflow->context();

    ##! 64: 'context: ' . Dumper( $context  )

    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    my $ca_alias = $context->param( 'ca_alias' );

    if (!$ca_alias) {
       OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_NICE_CRLISSUANCE_NO_CA_ID",
        );
    }
    ##! 16: 'CRL for alias ' . $ca_alias

    CTX('log')->application()->info("start crl issue for ca $ca_alias, workflow " . $workflow->id);

    my $param = $self->param();
    delete $param->{'ca_alias'};
    ##! 32: 'Extra params ' . Dumper $param

    my $set_context = $nice_backend->issueCRL( $ca_alias, $param );

    if(!$set_context) {

        my $error = $nice_backend->get_last_error() || 'I18N_OPENXPKI_UI_NICE_BACKEND_ERROR';

        # Catch exception as "pause" if configured
        if ($self->param('pause_on_error')) {
            CTX('log')->application()->warn("NICE IssueCRL failed but pause_on_error is requested ");
            CTX('log')->application()->debug("Original error: " . $error);
            $self->pause('I18N_OPENXPKI_UI_PAUSED_CERTSIGN_TOKEN_SIGNING_FAILED');
        }

        if (my $exc = OpenXPKI::Exception->caught()) {
            $exc->rethrow();
        } else {
            OpenXPKI::Exception->throw( message => $error );
        }
    }


    ##! 64: 'Setting Context ' . Dumper $set_context
    #while (my ($key, $value) = each(%$set_context)) {
    foreach my $key (keys %{$set_context} ) {
        my $value = $set_context->{$key};
        $context->param( { $key => $value } );
    }

}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::IssueCRL;

=head1 Description

Activity to initate CRL issuance using the configured NICE backend.

See OpenXPKI::Server::NICE::issueCRL for details

=head1 Parameters

=head2 Input

All parameters except ca_alias, are mapped to the backend as is. Please
check the documentation of the used backend for available parameters. 

=over

=item ca_alias (optional)

the ca alias to genrate the CRL for, if not given the context value for
I<ca_alias> is used.

=back

=head2 Output

=over

=item crl_serial - the serial number of the issued crl or I<pending>

=back

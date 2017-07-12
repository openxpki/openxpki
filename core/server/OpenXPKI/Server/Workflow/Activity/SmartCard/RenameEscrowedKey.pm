# OpenXPKI::Server::Workflow::Activity::SmartCard::RenameEscrowedKey;
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::RenameEscrowedKey;

use strict;
use English;

use base qw( OpenXPKI::Server::Workflow::Activity );


use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DateTime;
use DateTime;
use Template;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params     = {
      PKI_REALM => CTX('api')->get_pki_realm(),
      NEWKEY => $context->param('cert_identifier'),
      NAMESPACE => 'certificate.privatekey',
      EXPIRATION_DATE => undef
    };

    $params->{NAMESPACE} = $self->param('ds_namespace') if ($self->param('ds_namespace'));


    my $cert_escrow_handle_context = OpenXPKI::Server::Workflow::WFObject::WFHash->new(
                { workflow => $workflow , context_key => 'cert_escrow_handle' } );

    # Fetch the temporary keyhandle, stored with the csr_serial as key
    $params->{KEY} = $cert_escrow_handle_context->valueForKey( $context->param('csr_serial') );

    ##! 16: 'modify_data_pool_entry params: ' . Dumper $params
    CTX('api')->modify_data_pool_entry($params);

    CTX('log')->application()->info("SmartCard escrow key renamed for csr_serial " . $context->param('csr_serial'));


    return 1;
}

1;

__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::RenameEscrowedKey

=head1 Description

Reads the used temporary key handle from from the cert_escrow_handle hash
in the context and renames the datastore item to use the identifier of the
newly issued certificate.
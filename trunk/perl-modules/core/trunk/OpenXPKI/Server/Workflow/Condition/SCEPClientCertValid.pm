# OpenXPKI::Server::Workflow::Condition::SCEPClientCertValid.pm
# Written by Alexander Klink for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::SCEPClientCertValid;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();
    my $signer_identifier = $context->param('current_identifier');
    my $pki_realm = CTX('session')->get_pki_realm();
    ##! 16: 'signer_identifier: ' . $signer_identifier

    my $certs = CTX('dbi_backend')->select(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'IDENTIFIER',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $signer_identifier,
            'PKI_REALM'  => $pki_realm,
            'STATUS'     => 'ISSUED',
        },
        'VALID_AT' => time(),
    );
    ##! 64: 'certs: ' . Dumper $certs
    if (ref $certs ne 'ARRAY' || scalar @{ $certs } != 1) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEP_CLIENT_CERT_VALID_SIGNER_CERT_INVALID',
        );
    }
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SCEPClientCertValid

=head1 SYNOPSIS

<action name="do_something">
  <condition name="scep_client"
             class="OpenXPKI::Server::Workflow::Condition::SCEPClientCertValid">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether the signature certificate used for an
SCEP client request is currently valid.

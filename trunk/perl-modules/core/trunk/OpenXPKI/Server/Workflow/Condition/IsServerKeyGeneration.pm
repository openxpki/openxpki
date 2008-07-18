# OpenXPKI::Server::Workflow::Condition::IsServerKeyGeneration
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::IsServerKeyGeneration;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context  = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)
    my $pkcs10 = $context->param('pkcs10');
    my $spkac  = $context->param('spkac');

    if (defined $pkcs10) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISSERVERKEYGENERATION_NO_SERVER_KEYGEN_PKCS10_DEFINED');
    }
    if (defined $spkac) {
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISSERVERKEYGENERATION_NO_SERVER_KEYGEN_SPKAC_DEFINED');
    }
    return 1;
    ##! 16: 'end'
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsServerKeyGeneration

=head1 SYNOPSIS

<action name="do_something">
  <condition name="server_key_generation"
             class="OpenXPKI::Server::Workflow::Condition::IsServerKeyGeneration">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether a key generation on the server is required.
This is the case if either the pkcs10 or spkac context parameters are
defined. Otherwise, this condition fails.

# OpenXPKI::Server::Workflow::Condition::SCEPClient.pm
# Written by Alexander Klink for the OpenXPKI project 2009
# Copyright (c) 2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::SCEPClient;

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
    my $pki_realm = CTX('session')->get_pki_realm();

    my $cfg_id = CTX('api')->get_config_id({ ID => $workflow->id() });
    ##! 64: 'cfg_id: ' . $cfg_id

    my $signer_role = $context->param('current_role');
    ##! 16: 'signer_role: ' . $signer_role
    my $server      = $context->param('server');
    ##! 16: 'server: ' . $server

    my $autoissuance_role = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{scep}->{id}->{$server}->{'scep_client'}->{'autoissuance_role'};
    ##! 16: 'autoissuance role: ' . defined $autoissuance_role ? $autoissuance_role : 'undef'
    if (defined $autoissuance_role && $autoissuance_role eq $signer_role) {
        # SCEP Client with automatic issuance
        $context->param('scep_client_type' => 'autoissuance');
        return 1;
    }

    my $enrollment_role = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{scep}->{id}->{$server}->{'scep_client'}->{'enrollment_role'};
    ##! 16: 'enrollment role: ' . defined $enrollment_role ? $enrollment_role : 'undef'
    if (defined $enrollment_role && $enrollment_role eq $signer_role) {
        # SCEP Client with enrollment that still needs approval
        $context->param('scep_client_type' => 'enrollment');
        return 1;
    }

    ##! 16: 'end'
    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SCEPCLIENT_NOT_AN_SCEPCLIENT_REQUEST',
    );
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SCEPClient

=head1 SYNOPSIS

<action name="do_something">
  <condition name="scep_client"
             class="OpenXPKI::Server::Workflow::Condition::SCEPClient">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether an SCEP request is a SCEP Client request
(i.e. a request signed not by a certificate that was meant to be used
for allowing certificate requests or automatic issuance via SCEP) or not
(otherwise, it is a "normal" renewal, signed with an "old" certificate).

It does so by checking the role of the signer certificate against the
possible roles used for SCEP clients which are defined in the configuration.

It sets the context parameter scep_client_type either to 'autoissuance'
or 'enrollment', depending on the role of the signer certificate. This
value is in turn checked by the SCEPClientEnrollment and SCEPClientAutoIssuance
conditions.

# OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Crypto::X509;

use English;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)
    my $scep_server = $context->param('server');
    my $current_identifier = $context->param('current_identifier');
    my $pki_realm = CTX('session')->get_pki_realm(); 
    my $cfg_id = CTX('api')->get_config_id({ ID => $workflow->id() });

    my $pkcs7 = $context->param('pkcs7_content');
    $pkcs7 = "-----BEGIN PKCS7-----\n" . $pkcs7 . "-----END PKCS7-----\n";

    ##! 32: 'pkcs7: ' . $pkcs7
    my $scep_token = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{scep}->{id}->{$scep_server}->{crypto}; 
    my $signer_cert = $scep_token->command({
            COMMAND => 'get_signer_cert',
            PKCS7   => $pkcs7,
        });
    ##! 64: 'signer_cert: ' . $signer_cert

    my $tm = CTX('crypto_layer');
    my $default_token = $tm->get_token(
        TYPE      => 'DEFAULT',
        PKI_REALM => $pki_realm,
    );

    my $x509 = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $signer_cert,
    );

    my $signer_cert_identifier = $x509->get_identifier();
    ##! 16: 'signer cert identifier: ' . $signer_cert_identifier

    if (!defined $signer_cert_identifier || $signer_cert_identifier eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SIGNEDUSINGORIGINALCERTORSELFSIGNED_COULD_NOT_ESTABLISH_SIGNER_CERT_ID',
	    log => {
		logger => CTX('log'),
		priority => 'info',
		facility => 'system',
	    },
        );
    }

    if ($signer_cert_identifier ne $current_identifier) {
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_SIGNEDUSINGORIGINALCERTORSELFSIGNED_SELF_SIGNED');
    }
    ##! 16: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned

=head1 SYNOPSIS

<action name="do_something">
  <condition name="signed_using_original_cert"
             class="OpenXPKI::Server::Workflow::Condition::SignedUsingOriginalCertOrSelfSigned">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether a renewal SCEP request (PKCS#7) is signed
with the selected original, currently valid certificate.
It returns true if the signature is valid and the signature certificate
matches the original certificate.

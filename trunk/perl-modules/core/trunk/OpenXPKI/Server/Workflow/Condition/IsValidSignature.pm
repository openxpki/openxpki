# OpenXPKI::Server::Workflow::Condition::IsValidSignature.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::IsValidSignature;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;

use English;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)
    my $pkcs7tool = $context->param('pkcs7tool');
    my $pki_realm = CTX('session')->get_pki_realm(); 
    my $config_id = CTX('api')->get_config_id({ ID => $workflow->id() });

    my $csr_subject = $context->param('csr_subject');
    ##! 16: 'csr_subject: ' . $csr_subject

     my $tm = CTX('crypto_layer');
 
     my $pkcs7 = $context->param('pkcs7_content');
     $pkcs7 = "-----BEGIN PKCS7-----\n" . $pkcs7 . "-----END PKCS7-----\n";

     ##! 32: 'pkcs7: ' . $pkcs7
     my $pkcs7_token = $tm->get_token(
         TYPE      => 'PKCS7',
         ID        => $pkcs7tool,
         PKI_REALM => $pki_realm,
         CONFIG_ID => $config_id,
     );
     my $sig_subject = $pkcs7_token->command({
         COMMAND => 'get_subject',
         PKCS7   => $pkcs7,
    });
    ##! 64: 'sig_subject: ' . $sig_subject
    my $sig_valid;

    eval {
        $pkcs7_token->command({
            COMMAND => 'verify',
            PKCS7   => $pkcs7,
        });
    };
    if ($EVAL_ERROR) {
        ##! 4: 'signature invalid: ' . $EVAL_ERROR
	CTX('log')->log(
	    MESSAGE => "Invalid SCEP signature; CSR subject: $csr_subject, signature subject: $sig_subject",
	    PRIORITY => 'info',
	    FACILITY => 'audit',
	    );
        condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISVALIDSIGNATUREWITHREQUESTEDDN_INVALID_SIGNATURE_OR_NON_MATCHING_DNS');
    }
     
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsValidSignature

=head1 SYNOPSIS

<action name="do_something">
  <condition name="valid_signature_with_requested_dn"
             class="OpenXPKI::Server::Workflow::Condition::IsValidSignature">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether an SCEP request (PKCS#7) has a valid
signature (self-signed is OK) with a certificate with the same subject
DN as the one used in the certificate signing request within the PKCS#7
structure.

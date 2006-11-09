# OpenXPKI::Server::Workflow::Condition::IsValidSignatureWithRequestedDN.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$
package OpenXPKI::Server::Workflow::Condition::IsValidSignatureWithRequestedDN;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug 'OpenXPKI::Server::API::Workflow::Condition::IsValidSignatureWithRequestedDN';
use OpenXPKI::DN;
use OpenXPKI::Crypto::TokenManager;

use English;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)
    my $pkcs7tool = $context->param('pkcs7tool');
    my $pki_realm = CTX('session')->get_pki_realm(); 

    ##! 16: 'my condition name: ' . $self->name()
    my $negate = 0;
    if ($self->name() eq 'invalid_signature_or_requested_dn') {
        $negate = 1;
    }

    my $csr_subject = $context->param('csr_subject');
    ##! 16: 'csr_subject: ' . $csr_subject

     my $tm = OpenXPKI::Crypto::TokenManager->new();
 
     my $pkcs7 = $context->param('pkcs7_content');
     $pkcs7 = "-----BEGIN PKCS7-----\n" . $pkcs7 . "-----END PKCS7-----\n";

     ##! 32: 'pkcs7: ' . $pkcs7
     my $pkcs7_token = $tm->get_token(
         TYPE => 'PKCS7',
         ID   => $pkcs7tool,
         PKI_REALM => $pki_realm,
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
    }
    else {
        ##! 16: 'signature valid'
        $sig_valid = 1;
    }
     
    if ($negate == 1) { # we are asked if this is an invalid sig or the
                        # DNs don't match
        ##! 16: 'negate=1'
        if (defined $sig_valid && ($csr_subject eq $sig_subject)) {
            ##! 16: 'valid and matching'
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISVALIDSIGNATUREWITHREQUESTEDDN_VALID_SIGNATURE_AND_MATCHING_DNS');
        }
    }
    else {
        ##! 16: 'negate=0'
        if (! defined $sig_valid || ($csr_subject ne $sig_subject)) {
            ##! 16: 'invalid or not matching'
            condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_ISVALIDSIGNATUREWITHREQUESTEDDN_INVALID_SIGNATURE_OR_NON_MATCHING_DNS');
        }
    }
    ##! 16: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::IsValidSignatureWithRequestedDN

=head1 SYNOPSIS

<action name="do_something">
  <condition name="valid_signature_with_requested_dn"
             class="OpenXPKI::Server::Workflow::Condition::IsValidSignatureWithRequestedDN">
  </condition>
</action>

=head1 DESCRIPTION

This condition checks whether an SCEP request (PKCS#7) has a valid
signature (self-signed is OK) with a certificate with the same subject
DN as the one used in the certificate signing request within the PKCS#7
structure.
If the condition name is "valid_signature_with_requested_dn", it returns
true if the signature is valid and the signature DN matches the request
DN. If the condition name is "invalid_signature_or_requested_dn", the
condition works in exactly the opposite way.

# OpenXPKI::Server::Workflow::Activity::SCEP::ExtractCSR
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEP::ExtractCSR;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::CSR;
use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $pki_realm  = CTX('session')->get_pki_realm();
    my $cfg_id     = $self->config_id();

    my $context   = $workflow->context();
    my $server    = $context->param('server');

    # set pkcs7tool for later usage
    $context->param(
        'pkcs7tool' => $self->param('pkcs7tool'),
    );

    my $tm = CTX('crypto_layer');

    my $pkcs7 = $context->param('pkcs7_content');
    chomp($pkcs7);
    $pkcs7 = "-----BEGIN PKCS7-----\n" . $pkcs7 . "\n-----END PKCS7-----\n";
    ##! 32: 'pkcs7: ' . $pkcs7

    my $scep_token = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{scep}->{id}->{$server}->{crypto}; 

    my $pkcs10 = $scep_token->command({
        COMMAND => 'get_pkcs10',
        PKCS7   => $pkcs7,
    });

    if (! defined $pkcs10 || $pkcs10 eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SCEP_EXTRACTCSR_PKCS10_UNDEFINED',
        );
    }
    $context->param('pkcs10' => $pkcs10);

    # extract subject from CSR and add a context entry for it
    my $csr_obj = OpenXPKI::Crypto::CSR->new(
        DATA  => $pkcs10,
        TOKEN => CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{crypto}->{default},
    );
    ##! 32: 'csr_obj: ' . Dumper $csr_obj
    my $subject = $csr_obj->get_parsed('BODY', 'SUBJECT');
    $context->param('csr_subject' => $subject);
    $context->param('csr_type'    => 'pkcs10');
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEP::ExtractCSR

=head1 Description

This activity extracts the PKCS#10 CSR and the subject from the
SCEP message and saves it in the workflow context.

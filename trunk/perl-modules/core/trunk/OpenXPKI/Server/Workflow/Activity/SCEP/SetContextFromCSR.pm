# OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromCSR
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromCSR;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $pki_realm  = CTX('session')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my $context   = $workflow->context();
    my $csr       = $context->param('pkcs10');

    my $csr_obj = OpenXPKI::Crypto::CSR->new(
        DATA  => $csr,
        TOKEN => CTX('pki_realm_by_cfg')->{$self->config_id()}->{$pki_realm}->{crypto}->{default},
    );
    ##! 32: 'csr_obj: ' . Dumper $csr_obj
    my $subject = $csr_obj->get_parsed('BODY', 'SUBJECT');
    $context->param('cert_subject' => $subject);
    if (! defined $context->param('cert_role')) {
        # only set if it hasn't been set yet (by the user in the CSR,
        # for example)
        # FIXME - the role to set should maybe be a config option
        $context->param('cert_role' => '');
    }

    my @subject_alt_names = $csr_obj->get_subject_alt_names();

    ##! 64: 'subject_alt_names: ' . Dumper(\@subject_alt_names)
    
    $context->param('cert_subject_alt_name' =>
                    $serializer->serialize(\@subject_alt_names));

    my $sources = {
        'cert_subject'           => 'USER',
        'cert_role'              => 'EXTERNAL', # ?
        #'cert_subject_alt_name'  => 'USER',
        'cert_subject_alt_name_parts'  => 'USER',
    };
    $context->param('sources' =>
                    $serializer->serialize($sources));
 
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromCSR

=head1 Description

This activity sets the relevant context fields used for certificate
issuance from the given PKCS#10 data in the workflow context field.

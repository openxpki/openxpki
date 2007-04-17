# OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromOriginalCert
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromOriginalCert;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromOriginalCert';
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $pki_realm  = CTX('session')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $context    = $workflow->context();
    my $identifier = $context->param('current_identifier');
    my $dbi         = CTX('dbi_backend');

    # select current certificate from database
    my $cert = $dbi->first(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'SUBJECT',
            'ROLE',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $identifier,
            'STATUS'    => 'ISSUED',
            'PKI_REALM' => $pki_realm,
        },
    );

    $context->param('cert_subject' => $cert->{SUBJECT});
    $context->param('cert_role' => $cert->{ROLE}); 

    # select subject alt names from database
    my $sans = $dbi->select(
        TABLE   => 'CERTIFICATE_ATTRIBUTES',
        COLUMNS => [
            'ATTRIBUTE_VALUE',
        ],
        DYNAMIC => {
            'ATTRIBUTE_KEY' => 'subject_alt_name',
            'IDENTIFIER'    => $identifier,
        },
    );

    ##! 64: 'sans: ' . Dumper $sans
    my @subject_alt_names;
    if (defined $sans) {
        foreach my $san (@{$sans}) {
            my @split = split q{:}, $san->{'ATTRIBUTE_VALUE'};
            push @subject_alt_names, \@split;
        }
    }
#    my @subject_alt_names = $self->_get_san_array_from_csr_obj($csr_obj);

#    ##! 64: 'subject_alt_names: ' . Dumper(\@subject_alt_names)
    
    $context->param('cert_subject_alt_name' =>
                    $serializer->serialize(\@subject_alt_names));

    my $sources = {
        'cert_subject'           => 'EXTERNAL',
        'cert_role'              => 'EXTERNAL',
        'cert_subject_alt_name_parts'  => 'EXTERNAL',
    };
    $context->param('sources' =>
                    $serializer->serialize($sources));
 
    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEP::SetContextFromOriginalCert

=head1 Description

This activity sets the relevant context fields used for certificate
issuance from the currently valid certificate given in the context
field current_identifier.

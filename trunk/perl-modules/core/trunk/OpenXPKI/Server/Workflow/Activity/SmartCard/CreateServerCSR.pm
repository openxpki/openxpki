# OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR';
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my @cert_profiles = split /,/, $self->param('cert_profiles');
    my @cert_roles    = split /,/, $self->param('cert_roles');

    my $cert_issuance_data_ser = $context->param('cert_issuance_data');
    my @cert_issuance_data;
    if (defined $cert_issuance_data_ser) {
        ##! 4: 'cert_issuance_data_ser defined'
        @cert_issuance_data = @{$serializer->deserialize($cert_issuance_data_ser)};
    }
    else { # first time, write the number of certificates to the
           # workflow context
        $context->param('nr_of_certs' => scalar @cert_profiles);
    }
    my $current_pos = scalar @cert_issuance_data;
    
    my $cert_subject = $self->param('cert_subject');
    # replace every %var% occurence with the corresponding
    # value from the ldap_... variables in the workflow context
    while (my ($var) = ($cert_subject =~ m{ %(.*?)% }xms)) {
        my $value = $context->param("ldap_$var") || '';
        $cert_subject =~ s{ %$var% }{ $value }xmse;
    }
    ##! 16: 'cert_subject: ' . $cert_subject

    my $cert_subj_alt_names = $self->param('cert_subject_alt_names');
    while (my ($var) = ($cert_subj_alt_names =~ m{ %(.*?)% }xms)) {
        my $value = $context->param("ldap_$var") || '';
        $cert_subj_alt_names =~ s{ %$var% }{ $value }xmse;
    }
    ##! 16: 'cert_subj_alt_names: ' . $cert_subj_alt_names
    my @sans = split /,/, $cert_subj_alt_names;
    foreach my $entry (@sans) {
        my @tmp_array = split /=/, $entry;
        $entry = \@tmp_array;
    }
    ##! 16: '@sans: ' . Dumper(\@sans)
    
    my $cert_issuance_hash_ref = {
        'pkcs10'                => $context->param('pkcs10'),
        'csr_type'              => 'pkcs10',
        'cert_profile'          => $cert_profiles[$current_pos],
        'cert_role'             => $cert_roles[$current_pos],
        'cert_subject'          => $cert_subject,
        'cert_subject_alt_name' => \@sans,
    };
    ##! 16: 'cert_iss_hash_ref: ' . Dumper($cert_issuance_hash_ref)
    push @cert_issuance_data, $cert_issuance_hash_ref;
    ##! 16: 'cert_issuance_data: ' . Dumper(\@cert_issuance_data)
    $context->param(
        'cert_issuance_data' => $serializer->serialize(\@cert_issuance_data),
    );
    ##! 4: 'end'
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR

=head1 Description

This class takes the CSR from the client and sets up an array of
hashrefs in the context (cert_issuance_data) which contains all
information needed to persist them in the database and then fork
certificate issuance workflows.

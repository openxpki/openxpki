# OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::CreateServerCSR;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;
use Template;

sub execute {
    ##! 1: 'start'
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();

    my @cert_profiles = split(/,/, $self->param('cert_profiles'));
    my @cert_roles    = split(/,/, $self->param('cert_roles'));

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
    
    # prepare LDAP variable hashref for Template Toolkit
    my $ldap_vars;
    foreach my $param (keys %{ $context->param() }) {
        if ($param =~ s{ \A ldap_ }{}xms) {
            ##! 64: 'adding param ' . $param . ' to ldap_vars, value: ' . $context->param('ldap_' . $param)
            $ldap_vars->{$param} = $context->param('ldap_' . $param);
        }
    }
    # process subject using TT
    my $template = $self->param('cert_subject');
    my $tt = Template->new();
    my $cert_subject = '';
    $tt->process(\$template, $ldap_vars, \$cert_subject);
    ##! 16: 'cert_subject: ' . $cert_subject

    # process subject alternative names using TT
    $template = $self->param('cert_subject_alt_names');
    my $cert_subj_alt_names = '';
    $tt->process(\$template, $ldap_vars, \$cert_subj_alt_names);
    ##! 16: 'cert_subj_alt_names: ' . $cert_subj_alt_names

    my @sans = split(/,/, $cert_subj_alt_names);
    foreach my $entry (@sans) {
        my @tmp_array = split(/=/, $entry);
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

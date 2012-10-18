# OpenXPKI::Server::Workflow::Activity::SmartCard:PersistCSRs:
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::PersistCSRs;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute {
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi_backend');
    my $cert_iss_data = $context->param('cert_issuance_data');
    ##! 16: 'ref: ' . ref $cert_iss_data
    if (!defined $cert_iss_data) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PERSISTCSRS_CERT_ISSUANCE_DATA_UNDEFINED',
        );
    }
    
    my @cert_iss_data = @{$serializer->deserialize($cert_iss_data)};
    
    foreach my $csr_data (@cert_iss_data) {
        ##! 64: 'csr_data: ' . Dumper($csr_data)
        my $type    = $csr_data->{'csr_type'};
        my $profile = $csr_data->{'cert_profile'};
        my $subject = $csr_data->{'cert_subject'};
        my $role    = $csr_data->{'cert_role'};
        my $subj_alt_names = $csr_data->{'cert_subject_alt_name'};
        my $data    = $csr_data->{'pkcs10'};

        my @subj_alt_names = @{$subj_alt_names};
        ##! 16: '$subj_alt_names: ' . Dumper($subj_alt_names)
        ##! 16: '@subj_alt_names: ' . Dumper(\@subj_alt_names)

        my $csr_serial = $dbi->get_new_serial(
            TABLE => 'CSR',
        );

        # TODO: LOA (currently NULL)
        $dbi->insert(
                TABLE => 'CSR',
                HASH  => {
                    'PKI_REALM'  => $pki_realm,
                    'CSR_SERIAL' => $csr_serial,
                    'TYPE'       => $type,
                    'DATA'       => $data,
                    'PROFILE'    => $profile,
                    'SUBJECT'    => $subject,
                    'ROLE'       => $role,
                },
        );

        foreach my $san (@subj_alt_names) {
            ##! 64: 'san: ' . $san
            my $attrib_serial = $dbi->get_new_serial(
                    TABLE => 'CSR_ATTRIBUTES',
            );
            $dbi->insert(
                    TABLE => 'CSR_ATTRIBUTES',
                    HASH  => {
                        'ATTRIBUTE_SERIAL' => $attrib_serial,
                        'PKI_REALM'        => $pki_realm,
                        'CSR_SERIAL'       => $csr_serial,
                        'ATTRIBUTE_KEY'    => 'subject_alt_name',
                        'ATTRIBUTE_VALUE'  => $serializer->serialize($san),
                        'ATTRIBUTE_SOURCE' => 'EXTERNAL',
                    },
            );
        }
        my @csr_serials;
        my $csr_serial_context = $context->param('csr_serial');
        if (defined $csr_serial_context) {
            @csr_serials = @{$serializer->deserialize($csr_serial_context)};
        }
        $dbi->commit();
        push @csr_serials, $csr_serial;
        ##! 16: 'csr_serials: ' . Dumper(\@csr_serials)
        $context->param(
            'csr_serial' => $serializer->serialize(\@csr_serials),
        );
    }
    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::PersistCSRs

=head1 Description

persists the Certificate Signing Requests into the database, so that
they can then be used by the certificate issuance workflows.

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
use OpenXPKI::Server::Workflow::WFObject::WFHash;
use OpenXPKI::Server::Database; # to get AUTO_ID
use Data::Dumper;

sub execute {
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('api')->get_pki_realm();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $dbi        = CTX('dbi');
    my $cert_iss_data = $context->param('cert_issuance_data');
    ##! 16: 'ref: ' . ref $cert_iss_data
    if (!defined $cert_iss_data) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_PERSISTCSRS_CERT_ISSUANCE_DATA_UNDEFINED',
        );
    }

    my @cert_iss_data = @{$serializer->deserialize($cert_iss_data)};

    for my $csr_data (@cert_iss_data) {
        ##! 64: 'csr_data: ' . Dumper($csr_data)
        my $type    = $csr_data->{'csr_type'};
        my $profile = $csr_data->{'cert_profile'};
        my $subject = $csr_data->{'cert_subject'};
        my $subj_alt_names = $csr_data->{'cert_subject_alt_name'};
        my $data    = $csr_data->{'pkcs10'};

        my @subj_alt_names = @{$subj_alt_names};
        ##! 16: '$subj_alt_names: ' . Dumper($subj_alt_names)
        ##! 16: '@subj_alt_names: ' . Dumper(\@subj_alt_names)

        my $csr_serial = $dbi->next_id('csr');

        # TODO: LOA (currently NULL)
        $dbi->insert(
            into => 'csr',
            values => {
                pki_realm => $pki_realm,
                req_key   => $csr_serial,
                format    => $type,
                data      => $data,
                profile   => $profile,
                subject   => $subject,
            },
        );

        for my $san (@subj_alt_names) {
            ##! 64: 'san: ' . $san
            $dbi->insert(
                into => 'csr_attributes',
                values => {
                    attribute_key        => AUTO_ID,
                    pki_realm            => $pki_realm,
                    req_key              => $csr_serial,
                    attribute_contentkey => 'subject_alt_name',
                    attribute_value      => $serializer->serialize($san),
                    attribute_source     => 'EXTERNAL',
                },
            );
        }

        for my $validity_param (qw(notbefore notafter)) {
            next unless defined $context->param($validity_param);
            #my $source = $source_ref->{$validity_param};
            $dbi->insert(
                into => 'csr_attributes',
                values => {
                    attribute_key        => AUTO_ID,
                    pki_realm            => $pki_realm,
                    req_key              => $csr_serial,
                    attribute_contentkey => $validity_param,
                    attribute_value      => $context->param($validity_param),
                    attribute_source     => 'OPERATOR',
                },
            );
        }

        my $csr_serial_context = $context->param('csr_serial');
        my @csr_serials = defined $csr_serial_context
            ? ( @{$serializer->deserialize($csr_serial_context)} )
            : ();
        push @csr_serials, $csr_serial;
        ##! 16: 'csr_serials: ' . Dumper(\@csr_serials)
        $context->param(csr_serial => $serializer->serialize(\@csr_serials));

        # Link the escrow key handle to the csr_id
        if ($csr_data->{'escrow_key_handle'}) {
            ##! 16: 'Add escrow key handle ' . $csr_data->{'escrow_key_handle'}
            my $cert_escrow_handle_context = OpenXPKI::Server::Workflow::WFObject::WFHash->new(
                { workflow => $workflow , context_key => 'cert_escrow_handle' }
            );
            $cert_escrow_handle_context->setValueForKey( $csr_serial => $csr_data->{'escrow_key_handle'} );
        }

        CTX('log')->application()->info("SmartCard persisted csrs serials " .join(", ",@csr_serials));

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

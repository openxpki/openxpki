# OpenXPKI::Server::Workflow::Activity::SCEPv2::LoadRecentCertificate
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SCEPv2::LoadRecentCertificate;

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
    my $context    = $workflow->context();
    my $cert_identifier = $context->param('signer_cert_identifier');
    my $dbi         = CTX('dbi_backend');

    # select current certificate from database
    my $cert = $dbi->first(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'SUBJECT',
            'ROLE',
            'CSR_SERIAL',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $cert_identifier,
            'STATUS'    => 'ISSUED',
            #'PKI_REALM' => $pki_realm,
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
            'IDENTIFIER'    => $cert_identifier,
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

    # look up the certificate profile via the csr table
    ##! 32: ' Look for old csr: ' . $cert->{CSR_SERIAL}
    my $old_profile = $dbi->first(
        TABLE   => 'CSR',
        COLUMNS => [
            'PROFILE',
        ],
        DYNAMIC => {
            CSR_SERIAL => $cert->{CSR_SERIAL},
        }
    );
    ##! 64: 'CSR found : ' . Dumper $old_profile

    ##! 32: 'Found profile ' . $old_profile->{PROFILE}
    $context->param( 'cert_profile' =>  $old_profile->{PROFILE} );

    my $sources = $serializer->deserialize( $context->param('sources') );
    $sources->{'cert_role'} = 'SCEP-RENEWAL';
    $sources->{'cert_profile'} = 'SCEP-RENEWAL';
    $sources->{'cert_subject'} = 'SCEP-RENEWAL';
    $sources->{'cert_subject_alt_name_parts'}  = 'SCEP-RENEWAL';

    # TODO - This should be moved outside to the workflow
    # This is a replacement - so we copy the validity
    if (!$context->param('in_renew_window') && $context->param('in_replace_window')) {
        # cert hash contains epoch but we need absolute date!
        foreach my $validity_param (qw( notbefore notafter )) {
            my $validity = OpenXPKI::DateTime::convert_date({
                DATE       => DateTime->from_epoch( 'epoch' => $cert->{uc($validity_param)} ),
                OUTFORMAT => 'terse',
            });
            $context->param( $validity_param => $validity );
            $sources->{$validity_param} = 'SCEP-RENEWAL';

        }

        $context->param( 'renewal_mode' => 'replace' );

        # Check if we should to revoke the replaced certificate
        my $revoke_on_replace = CTX('config')->get_hash( ['scep', $context->param('server'), 'revoke_on_replace' ] );
        if (ref $revoke_on_replace eq 'HASH') {
            CTX('log')->log(
                MESSAGE => "SCEP certificate added for revocation due to replace " . $cert->{IDENTIFIER},
                PRIORITY => 'info',
                FACILITY => ['audit','application'],
            );
            # we use the context settings as in the CRR workflow,
            # so the activity can just pick them up
            $context->param( 'replace_cert_identifier' => $cert->{IDENTIFIER} );
            $context->param( 'reason_code' => $revoke_on_replace->{reason_code} );
            $context->param( 'invalidity_time' => $revoke_on_replace->{invalidity_time} || 0 );
        }

        CTX('log')->log(
            MESSAGE => "SCEP replace for old csr " . $cert->{CSR_SERIAL} . " with profile " . $old_profile->{PROFILE},
            PRIORITY => 'info',
            FACILITY => 'application',
        );
    } else {
        CTX('log')->log(
            MESSAGE => "SCEP renewal from old csr " . $cert->{CSR_SERIAL} . " with profile " . $old_profile->{PROFILE},
            PRIORITY => 'info',
            FACILITY => 'application',
        );
        $context->param( 'renewal_mode' => 'renew' );
    }

    $context->param('sources' => $serializer->serialize($sources));

    return 1;
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SCEP::LoadRecentCertificate

=head1 Description

This activity sets the relevant context fields used for certificate
issuance from the currently valid certificate given in the context
field current_identifier.
It overwrites the data extracted from the csr and sets the source
field to "SCEP-RENEWAL"

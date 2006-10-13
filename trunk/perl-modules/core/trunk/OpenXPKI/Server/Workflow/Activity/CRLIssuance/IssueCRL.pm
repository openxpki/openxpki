# OpenXPKI::Server::Workflow::Activity::CRLIsssuance::IssueCRL
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::CRLIssuance::IssueCRL;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CRLIssuance::IssueCRL';
use OpenXPKI::Crypto::Profile::CRL;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Crypto::TokenManager;
use OpenXPKI::Crypto::CRL;
use Date::Parse;

use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $context    = $workflow->context();
    my $dbi        = CTX('dbi_backend');

    my $context_ca_ids = $context->param('ca_ids');
    my $profile        = $context->param('_crl_profile');
    ##! 16: 'profile: ' . Dumper($profile)

    my $ca_ids_ref = $serializer->deserialize($context_ca_ids);
    if (!defined $ca_ids_ref) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_ISSUECRL_CA_IDS_NOT_DESERIALIZED",
        );
    }
    if (!ref $ca_ids_ref eq 'ARRAY') {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_ISSUECRL_CA_IDS_WRONG_TYPE",
        );
    }
    my @ca_ids = @{$ca_ids_ref};
    if (scalar @ca_ids == 0) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_ISSUECRL_CA_NO_CAS_LEFT",
        );
    }
    
    my $current_ca = $ca_ids[0];
    my $pki_realm = CTX('api')->get_pki_realm();
    my $ca_identifier = CTX('pki_realm')->{$pki_realm}->{ca}->{id}->{$current_ca}->{identifier};
    my $certificate = CTX('pki_realm')->{$pki_realm}->{ca}->{id}->{$current_ca}->{certificate};
    ##! 16: 'ca_identifier: ' . $ca_identifier
    my $tm = OpenXPKI::Crypto::TokenManager->new();
    my $ca_token = $tm->get_token(
        TYPE      => 'CA',
        ID        => $current_ca,
        PKI_REALM => $pki_realm,
        CERTIFICATE => $certificate,
    );

    # FIXME: iterate over all <issue_for> identifiers, if present

    # we want all identifiers and data for certificates that are
    # already in the certificate database with status 'REVOKED'

    # We need to select three different classes of certificates
    # for the CRL:
    # - those that are in the certificate DB with status 'REVOKED'
    #   and have a corresponding CRR entry, for those we also need
    #   the smallest approval date (works optimal using SQL MIN(), tbd)
    # - those that are in the certificate DB with status 'REVOKED'
    #   and for some reason DON't have a CRR entry. For those, the
    #   date is set to epoch 0
    # - those that are in the certificate DB with status
    #   'CRL_ISSUANCE_PENDING' and their smallest CRR approval date

    my @cert_timestamps; # array with certificate data and timestamp
    my $already_revoked_certs = $dbi->select(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'IDENTIFIER',
            'DATA'
        ],
        DYNAMIC => {
            'PKI_REALM'         => $pki_realm,
            'ISSUER_IDENTIFIER' => $ca_identifier,
            'STATUS'            => 'REVOKED',
        },
    );
    if (defined $already_revoked_certs) {
        ##! 16: 'already revoked certificates present'
        foreach my $cert (@{$already_revoked_certs}) {
            ##! 32: 'revoked cert: ' . Dumper $cert
            my $data       = $cert->{'DATA'};
            my $timestamp  = 0; # default if no approval date found
            my $identifier = $cert->{'IDENTIFIER'};
            my $earliest_approved_crr = $dbi->first(
                TABLE   => 'CRR',
                COLUMNS => [
                    'APPROVAL_DATE',
                ],
                DYNAMIC => {
                    'PKI_REALM'  => $pki_realm,
                    'IDENTIFIER' => $identifier,
                    'STATUS'     => 'APPROVED',
                },
            );
            if (defined $earliest_approved_crr) {
                $timestamp = $earliest_approved_crr->{'APPROVAL_DATE'};
                ##! 32: 'earliest approved crr present: ' . $timestamp
            }
            my $dt = DateTime->from_epoch(
                epoch => $timestamp,
            );
            push @cert_timestamps, [ $data, $dt->iso8601() ];
        }
    }
    ##! 16: 'cert_timestamps after first step: ' . Dumper(\@cert_timestamps)

    my $certs_to_be_revoked = $dbi->select(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'IDENTIFIER',
            'DATA'
        ],
        DYNAMIC => {
            'PKI_REALM'         => $pki_realm,
            'ISSUER_IDENTIFIER' => $ca_identifier,
            'STATUS'            => 'CRL_ISSUANCE_PENDING',
        },
    );
    if (defined $certs_to_be_revoked) {
        ##! 16: 'certificates to be freshly included in CRL present'
        foreach my $cert (@{$certs_to_be_revoked}) {
            ##! 32: 'cert to be revoked: ' . Dumper $cert
            my $data       = $cert->{'DATA'};
            my $timestamp  = 0; # default if no approval date found
            my $identifier = $cert->{'IDENTIFIER'};
            my $earliest_approved_crr = $dbi->first(
                TABLE   => 'CRR',
                COLUMNS => [
                    'APPROVAL_DATE',
                ],
                DYNAMIC => {
                    'PKI_REALM'  => $pki_realm,
                    'IDENTIFIER' => $identifier,
                    'STATUS'     => 'APPROVED',
                },
            );
            if (defined $earliest_approved_crr) {
                $timestamp = $earliest_approved_crr->{'APPROVAL_DATE'};
                ##! 32: 'earliest approved crr present: ' . $timestamp
            }
            my $dt = DateTime->from_epoch(
                epoch => $timestamp,
            );
            push @cert_timestamps, [ $data, $dt->iso8601() ];
            # set status in certificate db to revoked
            $dbi->update(
                TABLE => 'CERTIFICATE',
                DATA  => {
                    STATUS => 'REVOKED',
                },
                WHERE => {
                    IDENTIFIER => $identifier,
                },
            ); 
            $dbi->commit();
        }
    }
    ##! 32: 'cert_timestamps after 2nd step: ' . Dumper \@cert_timestamps 
        
    my $crl = $ca_token->command({
        COMMAND => 'issue_crl',
        REVOKED => \@cert_timestamps,
        PROFILE => $profile,
    });
    my $crl_obj = OpenXPKI::Crypto::CRL->new(
            TOKEN => $ca_token,
            DATA  => $crl,
    );
    ##! 128: 'crl: ' . Dumper($crl)

    my $serial = $dbi->get_new_serial(
            TABLE => 'CRL',
    );
    my %insert_hash = $crl_obj->to_db_hash();
    $insert_hash{'PKI_REALM'} = $pki_realm;
    $insert_hash{'ISSUER_IDENTIFIER'} = $ca_identifier;
    #$insert_hash{'TYPE'} = # FIXME: what is the meaning of this field?
    $insert_hash{'CRL_SERIAL'} = $serial;
    $insert_hash{'PUBLICATION_DATE'} = -1;
    $dbi->insert(
            TABLE => 'CRL',
            HASH  => \%insert_hash,
    ); 
    $dbi->commit();

    # publish_crl can then publish all those with a PUBLICATION_DATE of -1
    # and set it accordingly
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRLIssuance::IssueCRL

=head1 Description

This activity reads Certificate Revocation Requests (CRRs) from the
database and creates CRLs, which are then written to the CRL database
for the PublishCRL.pm activity to publish.

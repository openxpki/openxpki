# OpenXPKI::Server::Workflow::Activity::CRLIsssuance::IssueCRL
# Written by Alexander Klink for the OpenXPKI project 2006
# Optimized for performance by Martin Bartosch for OpenXPKI 2011
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CRLIssuance::IssueCRL;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Crypto::Profile::CRL;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Crypto::CRL;

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
    my $ca_identifier = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$pki_realm}->{ca}->{id}->{$current_ca}->{identifier};
    my $certificate = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$pki_realm}->{ca}->{id}->{$current_ca}->{certificate};
    ##! 16: 'ca_identifier: ' . $ca_identifier
    my $tm = CTX('crypto_layer');
    my $ca_token = $tm->get_token(
        TYPE      => 'CA',
        ID        => $current_ca,
        PKI_REALM => $pki_realm,
        CERTIFICATE => $certificate,
    );

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
	    'CERTIFICATE_SERIAL',
            'IDENTIFIER',
	    # 'DATA'
        ],
        DYNAMIC => {
            'PKI_REALM'         => $pki_realm,
            'ISSUER_IDENTIFIER' => $ca_identifier,
            'STATUS'            => 'REVOKED',
        },
    );
    if (defined $already_revoked_certs) {
        push @cert_timestamps,
                $self->__prepare_crl_data($already_revoked_certs);
    }
    ##! 16: 'cert_timestamps after first step: ' . Dumper(\@cert_timestamps)

    my $certs_to_be_revoked = $dbi->select(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
	    'CERTIFICATE_SERIAL',
            'IDENTIFIER',
            # 'DATA'
        ],
        DYNAMIC => {
            'PKI_REALM'         => $pki_realm,
            'ISSUER_IDENTIFIER' => $ca_identifier,
            'STATUS'            => 'CRL_ISSUANCE_PENDING',
        },
    );
    if (defined $certs_to_be_revoked) {
        push @cert_timestamps,
                $self->__prepare_crl_data($certs_to_be_revoked);
    }
    ##! 32: 'cert_timestamps after 2nd step: ' . Dumper \@cert_timestamps 
        
    my $serial = $dbi->get_new_serial(
            TABLE => 'CRL',
    );
    $profile->set_serial($serial);

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

    CTX('log')->log(
	MESSAGE => 'CRL issued for CA ' . $current_ca . ' in realm ' . $pki_realm,
	PRIORITY => 'info',
	FACILITY => [ 'audit', 'system' ],
	);


    my %insert_hash = $crl_obj->to_db_hash();
    $insert_hash{'PKI_REALM'} = $pki_realm;
    $insert_hash{'ISSUER_IDENTIFIER'} = $ca_identifier;
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

sub __prepare_crl_data {
    my $self = shift;
    my $certs_to_be_revoked = shift;

    my @cert_timestamps;
    my $dbi       = CTX('dbi_backend');
    my $pki_realm = CTX('session')->get_pki_realm();

    foreach my $cert (@{$certs_to_be_revoked}) {
        ##! 32: 'cert to be revoked: ' . Dumper $cert
        #my $data       = $cert->{'DATA'};
        my $serial      = $cert->{'CERTIFICATE_SERIAL'};
        my $revocation_timestamp  = 0; # default if no approval date found
        my $reason_code = '';
        my $invalidity_timestamp = '';
        my $identifier = $cert->{'IDENTIFIER'};
        my $crr = $dbi->last(
           TABLE => 'CRR',
            COLUMNS => [
                'REVOCATION_TIME',
                'REASON_CODE',
                'INVALIDITY_TIME',
            ],
            DYNAMIC => {
                'IDENTIFIER' => $identifier,
                'PKI_REALM'  => $pki_realm,
            },
        );
        if (defined $crr) {
            $revocation_timestamp = $crr->{'REVOCATION_TIME'};
            $reason_code          = $crr->{'REASON_CODE'};
            $invalidity_timestamp = $crr->{'INVALIDITY_TIME'};
            ##! 32: 'last approved crr present: ' . $revocation_timestamp
            push @cert_timestamps, [ $serial, $revocation_timestamp, $reason_code, $invalidity_timestamp ];
        }
        else {
            push @cert_timestamps, [ $serial ];
        }
        # update certificate database:
        my $status = 'REVOKED';
        if ($reason_code eq 'certificateHold') {
            $status = 'HOLD';
        }
        if ($reason_code eq 'removeFromCRL') {
            $status = 'ISSUED';
        }
        $dbi->update(
            TABLE => 'CERTIFICATE',
            DATA  => {
                STATUS => $status,
            },
            WHERE => {
                IDENTIFIER => $identifier,
            },
        ); 
        $dbi->commit();
    }
    return @cert_timestamps;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRLIssuance::IssueCRL

=head1 Description

This activity reads Certificate Revocation Requests (CRRs) from the
database and creates CRLs, which are then written to the CRL database
for the PublishCRL.pm activity to publish.

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
    my $pki_realm = CTX('api')->get_api('Session')->get_pki_realm();
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
    my $dbi = CTX('dbi_backend');
    my $revoked_certs = $dbi->select(
        TABLE   => [ 'CRR', 'CERTIFICATE' ],
        COLUMNS => [ 
                     'CERTIFICATE.IDENTIFIER',
                     'CRR.SUBMIT_DATE',
                     'CERTIFICATE.DATA',
                   ],
        JOIN    => [
                        [ 'IDENTIFIER', 'IDENTIFIER' ],
                   ],
        DYNAMIC => {
            'CRR.PKI_REALM' => $pki_realm,
            'CERTIFICATE.ISSUER_IDENTIFIER' => $ca_identifier,
        }
    );
    ##! 128: 'revoked_certs: ' . Dumper($revoked_certs)
    if (! defined $revoked_certs) {
        ##! 2: 'no revoked certs in db'
    }
    else {
        my @cert_timestamps;
        for (my $i = 0; $i < scalar @{$revoked_certs}; $i++) {
            # prepare array for token command
            my $cert = $revoked_certs->[$i];
            my $data      = $cert->{'CERTIFICATE.DATA'};
            my $timestamp = $cert->{'CRR.SUBMIT_DATE'};
            $cert_timestamps[$i] = [ $data, $timestamp ];
            # set status in certificate db to revoked
            $dbi->update(
                TABLE => 'CERTIFICATE',
                DATA  => {
                    STATUS => 'REVOKED',
                },
                WHERE => {
                    IDENTIFIER => $cert->{'CERTIFICATE.IDENTIFIER'},
                },
            ); 
            $dbi->commit();
        }
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
        $dbi->insert(
            TABLE => 'CRL',
            HASH  => \%insert_hash,
        ); 
        $dbi->commit();

        # publish_crl can then publish all those without PUBLICATION_DATE
        # and set it accordingly
    }
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

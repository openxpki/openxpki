# OpenXPKI::Server::Workflow::Activity::CRLIsssuance::PublishCRL
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Activity::CRLIssuance::PublishCRL;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CRLIssuance::PublishCRL';
use OpenXPKI::Serialization::Simple;
use OpenXPKI::FileUtils;
use OpenXPKI::Crypto::TokenManager;
use DateTime;

use Data::Dumper;

sub execute {
    ##! 1: 'execute'
    my $self       = shift;
    my $workflow   = shift;
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $context    = $workflow->context();

    my $context_ca_ids = $context->param('ca_ids');

    # TODO: avoid code duplication
    my $ca_ids_ref = $serializer->deserialize($context_ca_ids);
    if (!defined $ca_ids_ref) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_PUBLISHCRL_CA_IDS_NOT_DESERIALIZED",
        );
    }
    if (!ref $ca_ids_ref eq 'ARRAY') {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_PUBLISHCRL_CA_IDS_WRONG_TYPE",
        );
    }
    my @ca_ids = @{$ca_ids_ref};
    if (scalar @ca_ids == 0) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_PUBLISHCRL_CA_NO_CAS_LEFT",
        );
    }
    
    my $current_ca = $ca_ids[0];
    my $pki_realm = CTX('api')->get_pki_realm();
    my $ca_identifier = CTX('pki_realm')->{$pki_realm}->{ca}->{id}->{$current_ca}->{identifier};
    ##! 16: 'ca_identifier: ' . $ca_identifier
    my $crl_files = CTX('pki_realm')->{$pki_realm}->{ca}->{id}->{$current_ca}->{'crl_files'};
    ##! 16: 'ref crl_files: ' . ref $crl_files
    if (ref $crl_files ne 'ARRAY') {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_PUBLISHCRL_CRL_FILES_IS_NOT_ARRAYREF",
        );
    }
    # FIXME: iterate over all <issue_for> identifiers, if present
    my $dbi = CTX('dbi_backend');
    my $crl_db = $dbi->first(
        TABLE   => 'CRL',
        DYNAMIC => {
            'ISSUER_IDENTIFIER' => $ca_identifier,
        },
    );
    if (! defined $crl_db) {
	OpenXPKI::Exception->throw(
	    message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_PUBLISHCRL_NO_CRL_IN_DB",
        );
    }
    my $crl = $crl_db->{DATA};
    ##! 16: 'crl: ' . $crl

    foreach my $file (@{$crl_files}) {
        my $filename = $file->{FILENAME};
        my $format   = $file->{FORMAT};
        ##! 16: 'filename: ' . $filename
        ##! 16: 'format: ' . $format
        my $content;
        if ($format eq 'PEM') {
            $content = $crl;
        }
        elsif ($format eq 'DER') {
            my $tm = OpenXPKI::Crypto::TokenManager->new();
            my $default_token = $tm->get_token(
                TYPE      => 'DEFAULT',
                PKI_REALM => $pki_realm,
            );
            $content = $default_token->command({
                COMMAND => 'convert_crl',
                DATA    => $crl,
                OUT     => 'DER',
            });
        }
        else {
	    OpenXPKI::Exception->throw(
	        message => "I18N_OPENXPKI_ACTIVITY_CRLISSUANCE_PUBLISHCRL_UNSUPPORTED_OUTPUT_FORMAT",
            );
        }
        my $fu = OpenXPKI::FileUtils->new();
        $fu->write_file({
            FILENAME => $filename,
            CONTENT  => $content,
            FORCE    => 1,
        });
    }
    # set publication_date in CRL DB
    my $date = DateTime->now();
    $dbi->update(
        TABLE => 'CRL',
        DATA  => {
            'PUBLICATION_DATE' => $date->epoch(),
        },
        WHERE => {
            'ISSUER_IDENTIFIER' => $ca_identifier,
        },
    );
    $dbi->commit();

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CRLIssuance::PublishCRL

=head1 Description

This activity publishes the CRL to the filesystem (defined in the
crl_publication section in config.xml) and sets the publication date
in the CRL database.

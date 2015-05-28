# OpenXPKI::Server::Workflow::Validator::ApprovalSignature
# Written by Alexander Klink for the OpenXPKI project 2007
# Copyright (c) 2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Validator::ApprovalSignature;
use base qw( Workflow::Validator );

use strict;
use warnings;
use English;

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypto::X509;

use DateTime;
use Data::Dumper;
use Encode qw(encode decode);

__PACKAGE__->mk_accessors( qw(
                              signature_required
                              config_path
                             )
);

sub _init {
    my ( $self, $params ) = @_;
    # set config options
    if (exists $params->{'signature_required'}) {
        $self->signature_required($params->{'signature_required'});
    }
    if (exists $params->{'config_path'}) {
        $self->config_path($params->{'config_path'});
    }
    return 1;
}

sub validate {
    my ( $self, $wf, $role ) = @_;
    ## prepare the environment
    my $pki_realm = CTX('session')->get_pki_realm();
    my $context = $wf->context();
    my $sig      = $context->param('_signature');

    if (! defined $sig) {
        if  (! $self->signature_required()) {
            # signature is not required, validate OK
            return 1;
        }
        else {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVAL_SIGNATURE_SIGNATURE_NOT_DEFINED_BUT_REQUIRED',
                log     => {
                    logger   => CTX('log'),
                    priority => 'info',
                    facility => 'system',
                },
            );
        }
    }
    ##! 64: 'signature defined'
    ##! 64: 'signature: ' . $sig
    if ($sig !~ m{\A .* \n\z}xms) {
        ##! 64: 'sig does not end with \n, add it'
        $sig .= "\n";
    }
    my $sig_text = $context->param('_signature_text');
    ##! 64: 'signature text: ' . $sig_text

    # Check that signature is Base64 only
    if (! $sig =~ m{ \A [a-zA-Z\+/=]+ \z }xms) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVAL_SIGNATURE_SIGNATURE_CONTAINS_INVALID_CHARACTERS',
        log => {
        logger => CTX('log'),
        priority => 'warn',
        facility => 'system',
        },
        );
    }

    # Check that the signature text matches a given template

    my $wf_id   = $wf->id();
    my $wf_type = $wf->type();
    ##! 64: 'wf_id: ' . $wf_id
    ##! 64: 'wf_type: ' . $wf_type

    my $matched;
  CHECK_MATCH:
    foreach my $lang (qw(en_US de_DE ru_RU)) {
        ##! 64: 'testing language: ' . $lang
        my $match = CTX('api')->get_approval_message({
            WORKFLOW => $wf_type,
            ID       => $wf_id,
            LANG     => $lang,
        });
        ##! 64: 'match: ' . $match
        ##! 64: 'sig_text: ' . $sig_text
        if ($sig_text eq $match) {
            ##! 64: 'matches signature text'
            $matched = 1;
            last CHECK_MATCH;
        }
    }
    if (! $matched) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_PLAIN_TEXT_DOES_NOT_MATCH_REQUIRED_STRUCTURE',
            params  => {
                'RECEIVED' => $sig_text,
            },
            log     => {
                logger   => CTX('log'),
                priority => 'warn',
                facility => 'system',
            },
        );
    }

    my $pkcs7 = "-----BEGIN PKCS7-----\n"
              . $sig
              . "-----END PKCS7-----\n";


    ##! 32: 'pkcs7: ' . $pkcs7
    my $default_token = CTX('api')->get_default_token();

    $sig_text = encode('utf8', $sig_text);
    # Looks like CR is stripped by some browser which leads to a digest mismatch
    # when verifying the signature, so we strip \r here.
    $sig_text =~ s/\r//g;

    eval {
        $default_token->command({
            COMMAND => 'pkcs7_verify',
            NO_CHAIN => 1,
            PKCS7   => $pkcs7,
            CONTENT => $sig_text,
        });
    };
    if ($EVAL_ERROR) {
        ##! 4: 'signature invalid: ' . $EVAL_ERROR
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_SIGNATURE_INVALID',
            log     => {
                logger   => CTX('log'),
                priority => 'warn',
                facility => 'system',
            },
        );
    }
    ##! 16: 'signature valid'


    # Load trust anchors from config
    my $approval_config = $self->config_path();
    ##! 16: 'Load approval config from ' . $approval_config
    my $trust_anchors =  CTX('api')->get_trust_anchors({ PATH => $approval_config });


    # Looks like firefox adds \r to the p7
    $pkcs7 =~ s/\r//g;
    my $validate = CTX('api')->validate_certificate({
        PKCS7 => $pkcs7,
        ANCHOR => $trust_anchors,
    });

    ##! 32: 'validation result ' . Dumper $validate
    if ($validate->{STATUS}  ne 'TRUSTED') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_SIGNER_NOT_TRUSTED',
            params  => {
                'STATUS' => $validate->{STATUS}
            },
        );
    }

    ##! 64: 'signer_chain_server: ' . Dumper $validate->{CHAIN}

    ##! 32: 'signer pem ' . $validate->{CHAIN}->[0]

    my $x509_signer = OpenXPKI::Crypto::X509->new( DATA => $validate->{CHAIN}->[0], TOKEN => $default_token );
    my $signer_subject = $x509_signer->get_subject();
    my $signer_identifier = $x509_signer->get_identifier();

    ##! 32: 'signer cert pem: ' . $signer_subject

    if (! defined $signer_identifier  || $signer_identifier  eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_COULD_NOT_DETERMINE_SIGNER_CERTIFICATE_IDENTIFIER',
            log     => {
                logger   => CTX('log'),
                priority => 'info',
                facility => 'system',
            },
        );
    }


    ##! 16: 'end'
    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ApprovalSignature

=head1 SYNOPSIS

<action name="create_csr">
  <validator name="ApprovalSignature"
           class="OpenXPKI::Server::Workflow::Validator::ApprovalSignature">
  </validator>
</action>

=head1 DESCRIPTION

This validator checks whether a given signature for approval is
valid. It does this by running through the following checks:
- If no signature is defined and none required, it returns 1
- Else, it checks:
  - that the signature is in base64 format
  - that the signature text matches one of the translations given by the
    server
  - that the PKCS7 is a valid signature for the given text
  - that the certificate itself or a certificate in its trust chain
    is configured to be trusted
  - that the signer certificate is in the database and currently valid

Configuration:
The following parameters can be defined in the validator definition:
- signature_required: if true, enforce a signature on the approval
- pkcs7tool: the id of the pkcs7tool to use (see config.xml)
- trust_anchors: a comma-seperated list of trust anchor identifiers

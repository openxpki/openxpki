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
                              pkcs7tool
                              trust_anchors
                             )
);

sub _init {
    my ( $self, $params ) = @_;
    # set config options
    if (exists $params->{'signature_required'}) {
        $self->signature_required($params->{'signature_required'});
    }
    if (exists $params->{'pkcs7tool'}) {
        $self->pkcs7tool($params->{'pkcs7tool'});
    }
    if (exists $params->{'trust_anchors'}) {
        $self->trust_anchors($params->{'trust_anchors'});
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

    # Check that the signature is valid
    my $tm = CTX('crypto_layer');

    my $pkcs7 = "-----BEGIN PKCS7-----\n"
              . $sig
              . "-----END PKCS7-----\n";

    if (! defined $self->pkcs7tool()) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPOVALSIGNATURE_PKCS7TOOL_NOT_CONFIGURED',
            log     => {
                logger   => CTX('log'),
                priority => 'info',
                facility => 'system',
            },
        );
    }

    my $cfg_id = CTX('api')->get_config_id({ ID => $wf_id });
    ##! 32: 'pkcs7: ' . $pkcs7
    my $pkcs7_token = $tm->get_token(
        TYPE      => 'PKCS7',
        ID        => $self->pkcs7tool(),
        PKI_REALM => $pki_realm,
        CONFIG_ID => $cfg_id,
    );
    $sig_text = encode('utf8', $sig_text);
    eval {
        $pkcs7_token->command({
            COMMAND => 'verify',
            PKCS7   => $pkcs7,
            DATA    => $sig_text,
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
    my $signer_subject;
    eval {
        $signer_subject = $pkcs7_token->command({
            COMMAND => 'get_subject',
            PKCS7   => $pkcs7,
            DATA    => $sig_text,
        });
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_COULD_NOT_DETERMINE_SIGNER_SUBJECT',
            params  => {
                'ERROR' => $EVAL_ERROR,
            },
            log     => {
                logger   => CTX('log'),
                priority => 'info',
                facility => 'system',
            },
        );
    }
    ##! 16: 'signer subject: ' . $signer_subject
    $cfg_id = CTX('api')->get_config_id({ ID => $wf->id() });
    if (! defined $cfg_id) {
        # as this is called during creation, the cfg id is not defined
        # yet, so we use the current one
        $cfg_id = CTX('api')->get_current_config_id();
    }
    my $default_token = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{crypto}->{default};
    my @signer_chain = $default_token->command({
        COMMAND        => 'pkcs7_get_chain',
        PKCS7          => $pkcs7,
        SIGNER_SUBJECT => $signer_subject,
    });
    ##! 64: 'signer_chain: ' . Dumper \@signer_chain

    my $sig_identifier = OpenXPKI::Crypto::X509->new(
        TOKEN => $default_token,
        DATA  => $signer_chain[0]
    )->get_identifier();
    if (! defined $sig_identifier || $sig_identifier eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_COULD_NOT_DETERMINE_SIGNER_CERTIFICATE_IDENTIFIER',
            log     => {
                logger   => CTX('log'),
                priority => 'info',
                facility => 'system',
            },
        );
    }

    my @signer_chain_server;
    eval {
        @signer_chain_server = @{ CTX('api')->get_chain({
            START_IDENTIFIER => $sig_identifier,
        })->{IDENTIFIERS} };
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_COULD_NOT_DETERMINE_SIGNER_CHAIN_FROM_SERVER',
            log     => {
                logger   => CTX('log'),
                priority => 'info',
                facility => 'system',
            },
        );
    }
    ##! 64: 'signer_chain_server: ' . Dumper \@signer_chain_server

    my @temp_trust_anchors = split q{,}, $self->trust_anchors();
    if (! scalar @temp_trust_anchors) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_NO_TRUST_ANCHORS_DEFINED',
            log     => {
                logger   => CTX('log'),
                priority => 'info',
                facility => 'system',
            },
        );  
    }
    # FIXME - the code replacing the PKI realms is a duplication form
    # Authentication/X509.pm, this should only be in one place ...
    my $realms = CTX('pki_realm');
    my @pki_realms = keys %{ $realms };
    my @trust_anchors;
    ##! 16: 'pki_realms: ' . Dumper \@pki_realms
    foreach my $trust_anchor (@temp_trust_anchors) {
        if (grep { $_ eq $trust_anchor } @pki_realms) {
            ##! 16: $trust_anchor . ' is a PKI realm'
            # this trust anchor is not an identifier, but a PKI realm,
            # we'll have to replace it by all defined CAs for that realm
            my @ca_ids = keys %{ $realms->{$trust_anchor}->{ca}->{id} };
            foreach my $ca_id (@ca_ids) {
              ##! 16: 'ca_id: ' . $ca_id
              push @trust_anchors,
                $realms->{$trust_anchor}->{ca}->{id}->{$ca_id}->{identifier};
            }
        }
        else {
            ##! 16: $trust_anchor . ' seems to be an identifier'
            # just your regular identifier
            push @trust_anchors, $trust_anchor;
        }
    }
    ##! 64: 'trust anchors: ' . Dumper \@trust_anchors

    # Check that the certificate is trusted by going along the
    # chain and check whether one of the certificates in the chain
    # match one defined in trust_anchors
    my $anchor_found;
  CHECK_CHAIN:
    foreach my $identifier (@signer_chain_server) {
        ##! 16: 'identifier: ' . $identifier
        if (grep {$identifier eq $_} @trust_anchors) {
            $anchor_found = 1;
            last CHECK_CHAIN;
        }
    }
    if (! defined $anchor_found) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_UNTRUSTED_CERTIFICATE',
            params  => {
                'IDENTIFIER' => $sig_identifier,
            },
            log     => {
                logger   => CTX('log'),
                priority => 'warn',
                facility => 'system',
            },
        );
    }

    # Check that the signer certificate is in the database (so we
    # can look up its role later on) and valid now
    my $cert_db = CTX('dbi_backend')->first(
        TABLE    => 'CERTIFICATE',
        DYNAMIC  => {
            'IDENTIFIER' => $sig_identifier,
            'STATUS'     => 'ISSUED',
        },
        VALID_AT => time(),
    );
    if (! defined $cert_db) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_APPROVALSIGNATURE_SIGNER_CERT_NOT_FOUND_IN_DB_OR_INVALID',
            params  => {
                'IDENTIFIER' => $sig_identifier,
            },
            log     => {
                logger   => CTX('log'),
                priority => 'warn',
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

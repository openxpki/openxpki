# OpenXPKI::Server::Workflow::Condition::InitialEnrollmentOrRenewal.pm
# Written by Alexander Klink for the OpenXPKI project 2006
# rewritten by Alexander Klink for the OpenXPKI project in 2009
# Copyright (c) 2006,2009 by The OpenXPKI Project
package OpenXPKI::Server::Workflow::Condition::InitialEnrollmentOrRenewal;

use strict;
use warnings;
use base qw( Workflow::Condition );
use Workflow::Exception qw( condition_error configuration_error );
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use OpenXPKI::DN;
use English;

use DateTime;

use Data::Dumper;

sub evaluate {
    ##! 16: 'start'
    my ( $self, $workflow ) = @_;

    my $context   = $workflow->context();
    ##! 64: 'context: ' . Dumper($context)
    my $pki_realm = CTX('session')->get_pki_realm(); 

    my $cfg_id = CTX('api')->get_config_id({ ID => $workflow->id() });
    ##! 64: 'cfg_id: ' . $cfg_id

    my $pkcs7 = $context->param('pkcs7_content');
    $pkcs7 = "-----BEGIN PKCS7-----\n" . $pkcs7 . "-----END PKCS7-----\n";
    ##! 32: 'pkcs7: ' . $pkcs7

    my $pkcs7tool = $context->param('pkcs7tool');
    my $pkcs7_token = CTX('crypto_layer')->get_token(
        TYPE      => 'PKCS7',
        ID        => $pkcs7tool,
        PKI_REALM => $pki_realm,
        CONFIG_ID => $cfg_id,
    );
    my $sig_subject = $pkcs7_token->command({
            COMMAND => 'get_subject',
            PKCS7   => $pkcs7,
        });
    ##! 64: 'sig_subject: ' . $sig_subject

    my $default_token = CTX('pki_realm_by_cfg')->{$cfg_id}->{$pki_realm}->{crypto}->{default};
    
    my @signer_chain;
    eval {
        @signer_chain = $default_token->command({
            COMMAND        => 'pkcs7_get_chain',
            PKCS7          => $pkcs7,
            SIGNER_SUBJECT => $sig_subject,
        });
    };
    ##! 64: 'signer_chain: ' . Dumper \@signer_chain
    if ($EVAL_ERROR || scalar @signer_chain == 0) {
        ##! 64: 'could not get chain'

        # something is wrong, we would like to throw an exception,
        # but in a condition that would only mean that the condition
        # is false, i.e. a renewal, we'd rather return 1 instead
        # so that the request is treated as an initial enrollment ... 
        CTX('log')->log(
            MESSAGE  => 'SCEP pkcs7_get_chain failed ...',
            PRIORITY => 'error',
            FACILITY => 'system',
        );
        return 1;
    }
    my $sig_identifier;
    eval {
        $sig_identifier = OpenXPKI::Crypto::X509->new(
            TOKEN => $default_token,
            DATA  => $signer_chain[0],
        )->get_identifier();
    };
    if ($EVAL_ERROR || ! defined $sig_identifier) {
        ##! 64: 'could not get signature certificate identifier'

        # something is wrong, we would like to throw an exception,
        # but in a condition that would only mean that the condition
        # is false, i.e. a renewal, we'd rather return 1 instead
        # so that the request is treated as an initial enrollment ... 
        CTX('log')->log(
            MESSAGE  => 'SCEP get_identifier on signer cert failed ...',
            PRIORITY => 'error',
            FACILITY => 'system',
        );
        return 1;
    }
    # check whether the signature certificate is already in our database,
    # if not, this is an initial enrollment, otherwise it is a renewal
    my $certs = CTX('dbi_backend')->select(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'NOTAFTER',
            'SUBJECT',
        ],
        DYNAMIC => {
            'IDENTIFIER' => $sig_identifier,
            'PKI_REALM'  => $pki_realm,
        },
    );
    if (! ref $certs eq 'ARRAY') {
        ##! 64: 'dbi lookup went wrong'

        # something is wrong, we would like to throw an exception,
        # but in a condition that would only mean that the condition
        # is false, i.e. a renewal, we'd rather return 1 instead
        # so that the request is treated as an initial enrollment ... 
        CTX('log')->log(
            MESSAGE  => 'SCEP DBI lookup on signer identifier failed ...',
            PRIORITY => 'error',
            FACILITY => 'system',
        );
        return 1;
    }
    if (scalar @{ $certs } == 0) {
        ##! 64: 'no certificates for identifier ' . $sig_identifier . ' found, this is an initial enrollment'
        return 1;
    }
    $context->param('current_identifier' => $sig_identifier);
    ##! 16: 'current_notafter: ' . $certs->[0]->{NOTAFTER}
    $context->param('current_notafter' => $certs->[0]->{NOTAFTER});
    ##! 16: 'current_role: ' . $certs->[0]->{ROLE}
    $context->param('current_role' => $certs->[0]->{ROLE});

    ##! 16: 'current subject: ' . $certs->[0]->{SUBJECT}

    # look up all certificates with the subject of the signer certificates
    # that are currently valid to save the number of them in the workflow
    # - will be checked later by the correct_number_of_valid_certs condition
    my $current_certs = CTX('dbi_backend')->select(
        TABLE   => 'CERTIFICATE',
        COLUMNS => [
            'IDENTIFIER',
        ],
        DYNAMIC => {
            'SUBJECT'   => $certs->[0]->{SUBJECT},
            'STATUS'    => 'ISSUED',
            'PKI_REALM' => $pki_realm,
        },
        VALID_AT => time(),
    );
    ##! 64: 'current_certs: ' . Dumper $current_certs
    $context->param('current_valid_certificates' => scalar @{ $current_certs });

    condition_error('I18N_OPENXPKI_SERVER_WORKFLOW_CONDITION_INITIALENROLLMENTORRENEWAL_NO_INITIAL_ENROLLMENT_VALID_CERTIFICATE_PRESENT');
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::InitialEnrollmentOrRenewal

=head1 SYNOPSIS

<action name="do_something">
  <condition name="is_initial_enrollment"
             class="OpenXPKI::Server::Workflow::Condition::InitialEnrollmentOrRenewal">
  </condition>
</action>

=head1 DESCRIPTION

The condition checks if a SCEP request is an initial enrollment request
or a renewal.

This is done by looking up the signer certificate from the PKCS#7
data and checking whether it is already present in the certificate
database.

If it is, we are dealing with a renewal, if it is not, it is just
an initial enrollment.

In the renewal case, the condition also saves the signer certificate
identifier in the context parameter 'current_identifier', as well
as its notafter date in 'current_notafter'. It also saves the number
of currently valid certificates with the same DN as the signer certificate
in the 'current_valid_certificates' parameter.

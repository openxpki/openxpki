## Written 2011 by Oliver Welter <openxpki@oliwel.de>
## Based on  OpenXPKI::Server::Workflow::Condition::PKCS10;
## for the OpenXPKI project
## (C) Copyright 2011 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Condition::SubjectMatchesPKCS10;

use strict;
use warnings;
use base qw( Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Crypto::CSR;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub evaluate {

    ##! 1: 'start'
    my ( $self, $workflow ) = @_;

    my $context     = $workflow->context();

    my $subject  = $context->param('cert_subject');
    my $pkcs10  = $context->param('pkcs10');


    # allow empty pkcs10 for server-side key generation
    if (not $pkcs10)
    {
        return 1;
    }

    # parse PKCS#10 request
    my $default_token = CTX('api')->get_default_token();

    my $csr;
    eval {
    $csr = OpenXPKI::Crypto::CSR->new(
        TOKEN => $default_token,
        DATA => $pkcs10,
        );
    };
    if ($EVAL_ERROR) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_PARSE_ERROR",
            );
    }

    my $parsed_subject = $csr->get_parsed('SUBJECT');
    if (! defined $parsed_subject) {
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_PKCS10_PARSE_ERROR",
            );
    }

    CTX('log')->application()->debug("Subject mismatch $subject != $parsed_subject");


    condition_error( "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATOR_SUBJECT_MISMATCH_PKCS10" )
        if ( $subject != $parsed_subject );

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Condition::SubjectMatchesPKCS10

=head1 SYNOPSIS

<action name="CreateCSR">
  <validator name="SubjectMatchesPKCS10"
           class="OpenXPKI::Server::Workflow::Validator::SubjectMatchesPKCS10">
    <arg value="$cert_subject"/>
    <arg value="$pkcs10"/>
  </validator>
</action>

=head1 DESCRIPTION

This validator checks if the passed subject string is equal to the one
contained in the pkcs10 request. The validator assumes a properly formated
pkcs10 request, if you are unsure put OpenXPKI::Server::Workflow::Validator::PKCS10
in front of this validator.

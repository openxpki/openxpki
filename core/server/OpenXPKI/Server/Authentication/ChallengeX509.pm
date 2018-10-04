## OpenXPKI::Server::Authentication::ChallengeX509
##
## Rewritten 2013 by Oliver Welter for the OpenXPKI Project
## (C) Copyright 2013 by The OpenXPKI Project

package OpenXPKI::Server::Authentication::ChallengeX509;

use strict;
use warnings;
use English;

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypto::X509;
use MIME::Base64;

use Moose;

extends 'OpenXPKI::Server::Authentication::X509';

use Data::Dumper;


sub login_step {
    ##! 1: 'start'
    my $self    = shift;
    my $arg_ref = shift;

    my $name    = $arg_ref->{HANDLER};
    my $msg     = $arg_ref->{MESSAGE};

    if (! exists $msg->{PARAMS}->{CHALLENGE} ||
        ! exists $msg->{PARAMS}->{SIGNATURE}) {
        ##! 4: 'no login data received (yet)'
        # The challenge is just the session ID, so we do not have to
        # remember the challenge (which could only be done in the
        # session anyways as people might talk to different servers
        # in different login steps) ...
        my $challenge = CTX('session')->data->id;
        ##! 64: 'challenge: ' . $challenge
        # save the pending challenge to check later that we
        # received a valid challenge

        return (undef, undef,
            {
        SERVICE_MSG => "GET_X509_LOGIN",
        PARAMS      => {
                    NAME        => $self->{NAME},
                    DESCRIPTION => $self->{DESC},
                    CHALLENGE   => $challenge,
            },
            },
        );
    }


        ##! 2: 'login data / signature received'
        my $challenge = $msg->{PARAMS}->{CHALLENGE};
        my $signature = $msg->{PARAMS}->{SIGNATURE};
        my $pki_realm = CTX('session')->data->pki_realm;

        if ($signature !~ m{ \A .* \n \z }xms) {
            # signature does not end with \n, add it
            $signature .= "\n";
        }
        ##! 64: 'challenge: ' . $challenge
        ##! 64: 'signature: ' . $signature

        if ($challenge ne CTX('session')->data->id) {
            # the sent challenge is not for this session ID
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_CHALLENGE_DOES_NOT_MATCH_SESSION_ID',
                params  => {
                    CHALLENGE  => $challenge,
                    SESSION_ID => CTX('session')->data->id,
                },
            );
        }
        if (! $signature =~ m{ \A [a-zA-Z\+/=]+ \z }xms) {
            # the sent signature is not in Base64 format
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_SIGNATURE_IS_NOT_BASE64',
            );
        }
        my $pkcs7 =
              '-----BEGIN PKCS7-----' . "\n"
            . $signature
            . '-----END PKCS7-----';
        my $default_token = CTX('crypto_layer')->get_system_token({ TYPE => "DEFAULT" });

        ##! 64: ' Signature blob: ' . $pkcs7
        ##! 64: ' Challenge: ' . $challenge

        eval {
            # FIXME - this needs testing
            $default_token->command({
                COMMAND => 'pkcs7_verify',
                NO_CHAIN => 1,
                PKCS7   => $pkcs7,
                CONTENT => $challenge,
            });
        };
        if ($EVAL_ERROR) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_AUTHENTICATION_X509_INVALID_SIGNATURE',
            );
        }
        ##! 16: 'signature valid'


        # Looks like firefox adds \r to the p7
        $pkcs7 =~ s/\r//g;
        my $validate = CTX('api')->validate_certificate({
            PKCS7 => $pkcs7,
            ANCHOR => $self->trust_anchors(),
        });

        return $self->_validation_result( $validate );

}


1;
__END__

=head1 Name

OpenXPKI::Server::Authentication::ChallengeX509 - certificate based authentication.

=head1 Description

Send the user a challenge to be signed by the browser. Requires a supported browser.

See OpenXPKI::Server::Authentication::X509 for configuration options.

package OpenXPKI::Server::Workflow::Validator::PKCS10;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Validator );

use Workflow::Exception qw( validation_error );
use Crypt::PKCS10 2.000;
use MIME::Base64;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypt::PKCS7;


sub _validate {

    my ( $self, $wf, $pkcs10 ) = @_;

    # allow empty PKCS10 for server-side key generation
    if (not $pkcs10) {
        CTX('log')->application()->debug("PKCS#10 validaton: is empty");
        return 1;
    }

    my $verify_signature = not (defined $self->param('verify_signature') && !$self->param('verify_signature'));

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new($pkcs10,
        ignoreNonBase64 => 1,
        verifySignature => 0 );

    my $error;
    $error = Crypt::PKCS10->error unless($decoded);

    # try to unwrap as PKCS7 renewal request containers if allowed
    if (!$decoded && $self->param('unwrap_pkcs7')) {

        eval{
            ##! 16: 'try to parse a PKCS7'
            my $p7 = OpenXPKI::Crypt::PKCS7->new($pkcs10);
            ##! 128: $p7->envelope()
            $pkcs10 = $p7->payload();
            ##! 32: encode_base64($pkcs10)
            $decoded = Crypt::PKCS10->new( $pkcs10,
                ignoreNonBase64 => 1,
                verifySignature => 0 );

            die Crypt::PKCS10->error unless($decoded);
            $error = undef;
            CTX('log')->application()->info("Input was PKCS7 container, with valid PCKS10 payload");
        };
        $error = $EVAL_ERROR if($EVAL_ERROR);
    }

    if (!$decoded) {
        CTX('log')->application()->error("Invalid PKCS#10 request");
        CTX('log')->application()->trace($error);
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_PKCS10_PARSE_ERROR");
    }

    if ($verify_signature && !$decoded->checkSignature()) {
        CTX('log')->application()->error("Invalid signature on PKCS#10 request");
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_PKCS10_SIGNATURE_ERROR");
    }

    if (!($decoded->subject() || $self->param('empty_subject'))) {
        CTX('log')->application()->error('PKCS#10 has no subject');
        validation_error('I18N_OPENXPKI_UI_VALIDATOR_PKCS10_NO_SUBJECT_ERROR');
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::PKCS10

=head1 SYNOPSIS

validator:
  is_valid_pkcs10:
      class: OpenXPKI::Server::Workflow::Validator::PKCS10
      param:
         empty_subject: 0|1
         verify_signature: 0|1
      arg:
         - $pkcs10

=head1 DESCRIPTION

Check the incoming data to be a valid (parseable) pkcs10 request. By default,
the request must have a subject set, you can skip the subject check setting
the parameter empty_subject to a true value.

=head2 Argument

=over

=item $pkcs10

The PEM formatted PKCS#10 request

=back

=head2 Parameter

=over

=item empty_subject

By default, we expect the CSR to have a subject set. Set this to 0 to allow
an empty subject (required with some SCEP clients and Microsoft CA services).

=item verify_signature

Cryptographically verify the signature of the request - default is ON.
(was changed in v2.3 as the module deps have been fixed).

=item unwrap_pkcs7

Renewal requests made by e.g. windows servers come with the PEM headers
of a "normal" PKCS10 formatted request but are enveloped into a PKCS7
signature. When set to a true value, the class tries to detect wrapped
requests and validates the PKCS10 part.

It does B<not> make any signature checks on the PKCS7 structure!

=back

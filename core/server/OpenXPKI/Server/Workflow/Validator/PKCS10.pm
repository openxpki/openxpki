package OpenXPKI::Server::Workflow::Validator::PKCS10;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Validator );
use Workflow::Exception qw( validation_error );
use Crypt::PKCS10;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub _validate {

    my ( $self, $wf, $pkcs10 ) = @_;

    # allow non-defined PKCS10 for server-side key generation

    if (not defined $pkcs10) {
        CTX('log')->application()->debug("PKCS#10 validaton: is empty");

        return 1;
    }

    my $verify_signature = $self->param('verify_signature') ? 1 : 0;

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new($pkcs10,
        ignoreNonBase64 => 1,
        verifySignature => $verify_signature );

    if (!$decoded) {

        my $error = Crypt::PKCS10->error;
        $error =~ s/\s*$//;
        # Log the error
        CTX('log')->application()->error("Invalid PKCS#10 request ($error)");


        # If signature verification was on, check if it only the signature is the problem
        $decoded = Crypt::PKCS10->new($pkcs10,
            ignoreNonBase64 => 1,
            verifySignature => 0 );

        if ($decoded) {
              validation_error("I18N_OPENXPKI_UI_VALIDATOR_PKCS10_SIGNATURE_ERROR");
        }
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_PKCS10_PARSE_ERROR");
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

Cryptographically verify the signature of the request. This is off by
default as it is it requires additonal modules which are not part of the
OpenXPKI installation by default (Crypt::OpenSSL::RSA/DSA, Crypt::PK::ECC),
depending on the type of uploaded key.

=back


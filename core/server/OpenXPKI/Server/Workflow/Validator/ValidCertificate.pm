package OpenXPKI::Server::Workflow::Validator::ValidCertificate;

use strict;
use warnings;
use base qw( OpenXPKI::Server::Workflow::Validator );
use Workflow::Exception qw( validation_error );
use OpenXPKI::Crypt::X509;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Debug;
use English;

sub _validate {

    my ( $self, $wf, $pem ) = @_;

    # allow non-defined PKCS10 for server-side key generation

    if (not defined $pem) {
        CTX('log')->application()->debug("x509 validaton: is empty");
        return 1;
    }

    if ($pem !~ m{-----BEGIN[^-]*CERTIFICATE-----(.+)-----END[^-]*CERTIFICATE-----}xms ) {
        validation_error("I18N_OPENXPKI_UI_VALIDATOR_X509_PARSE_ERROR");
    }

    my $x509;
    eval { $x509 = OpenXPKI::Crypt::X509->new( $pem ); };

    if (!$x509 || $EVAL_ERROR) {

        my $error = $EVAL_ERROR;
        $error =~ s/\s*$//;
        # Log the error
        CTX('log')->application()->error("Invalid x509 import ($error)");

        validation_error("I18N_OPENXPKI_UI_VALIDATOR_X509_PARSE_ERROR");
    }


    my $subject = $self->param('subject');
    if ($subject) {
        CTX('log')->application()->debug("x509 validaton against subject $subject ");
        $subject = qr/\Q$subject\E/;
        if ($x509->get_subject() !~ $subject ) {
            CTX('log')->application()->error("x509 subject mismatch");
            validation_error("I18N_OPENXPKI_UI_VALIDATOR_X509_SUBJECT_MISMATCH_ERROR");
        }
    }

    my $subject_key_id = $self->param('subject_key_identifier');
    if ($subject_key_id) {
        CTX('log')->application()->debug("x509 validaton against subject key id $subject_key_id ");
        if (uc($subject_key_id) ne uc($x509->get_subject_key_id())) {
            CTX('log')->application()->error("x509 subject key id mismatch");
            validation_error("I18N_OPENXPKI_UI_VALIDATOR_X509_SUBJECT_KEY_ID_MISMATCH_ERROR");
        }
    }

    my $authority_key_id = $self->param('authority_key_identifier');
    if ($authority_key_id) {
        CTX('log')->application()->debug("x509 validaton against authority key id $authority_key_id ");
        if (uc($authority_key_id) ne uc($x509->get_authority_key_id())) {
            CTX('log')->application()->error("x509 authority key id mismatch");
            validation_error("I18N_OPENXPKI_UI_VALIDATOR_X509_AUTHORITY_KEY_ID_MISMATCH_ERROR");
        }
    }

    return 1;
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::Validator::ValidCertificate

=head1 SYNOPSIS

validator:
  is_valid_pkcs10:
      class: OpenXPKI::Server::Workflow::Validator::ValidCertificate
      param:
         subject: CN=test.me,O=ACME,C=DE
         subject_key_identifier: 53:56:9A:FB:A3:4E:2A:4C:DF:52:8B:F8:A6:9F:30:6E:4A:49:45:C0
         authority_key_identifier: 53:56:9A:FB:A3:4E:2A:4C:DF:52:8B:F8:A6:9F:30:6E:4A:49:45:C0
      arg:
         - $pem

=head1 DESCRIPTION

Check the incoming data to be a valid (parseable) x509 certificate.
Optionally check for certain properties.

=head2 Argument

=over

=item $pem

The PEM formatted x509 certificate

=back

=head2 Parameter

=over

=item subject

A string or regex to check the subject against.

=item subject_key_identifier

A string to match the subject key identifier against

=item authority_key_identifier

A string to match the authority key identifier against

=back


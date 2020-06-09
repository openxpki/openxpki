package OpenXPKI::Crypt::PKCS10;

use strict;
use warnings;
use English;

use OpenXPKI::DN;
use Math::BigInt;
use Digest::SHA qw(sha1_base64 sha1_hex);
use OpenXPKI::DateTime;
use MIME::Base64;
use Moose;
use Crypt::PKCS10 1.8;


has _pkcs10 => (
    is => 'ro',
    required => 1,
    isa => 'Crypt::PKCS10',
);

=head1 Name

OpenXPKI::Crypt::PKCS10

=head1 Description

Helper class to extract information from a PKCS10 request.

Expects PEM encoded data with headers or raw binary as single argument
to new.

=head1 Methods

=head2 data

The request binary data.

=cut

has data => (
    is => 'ro',
    required => 1,
    isa => 'Str',
);

=head2 pem

The PEM encoded request, 64 chars per line, with header and footer lines.

=cut

has pem => (
    is => 'ro',
    required => 0,
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $pem = encode_base64($self->data());
        $pem =~ s{\s}{}g;
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        chomp $pem;
        return "-----BEGIN CERTIFICATE REQUEST-----\n$pem\n-----END CERTIFICATE REQUEST-----";
    },
);

=head2 get_subject

The subject (full DN) of the request as string as defined in RFC2253

=cut

has subject => (
    is => 'ro',
    required => 0,
    isa => 'Str',
    reader => 'get_subject',
    lazy => 1,
    default => sub {
        my $self = shift;
        # we should improve Crypt::PKCS10 to return the desired format directly
        my $subject = $self->_pkcs10()->subject;
        return OpenXPKI::DN::convert_openssl_dn( $subject ) ;
    }
);

=head2 get_subject_key_id

Sha1 hash of the DER encoded public key. Uppercase hexadecimal with bytes
separated by a colon, e.g. A1:B2:C3....

=cut

has subject_key_id => (
    is => 'ro',
    required => 0,
    isa => 'Str',
    reader => 'get_subject_key_id',
    lazy => 1,
    default => sub {
        my $self = shift;
        return uc join ':', ( unpack '(A2)*', sha1_hex( $self->_pkcs10()->{certificationRequestInfo}{subjectPKInfo}{subjectPublicKey}[0] ) );
    }
);

=head2 get_csr_identifier

Same value as the transaction_id but encoded with base64 with "urlsafe"
encoding (+\ replaced by -_) as also used for the cert_identifier.

=cut

has csr_identifier => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_csr_identifier',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $csr_identifier = sha1_base64($self->data);
        ## RFC 3548 URL and filename safe base64
        $csr_identifier =~ tr/+\//-_/;
        return $csr_identifier;
    },
);

=head2 get_transaction_id

Return the transaction_id of which is defined as the sha1 hash over
the DER encoded request in hexadecimal format.

=cut

has transaction_id => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_transaction_id',
    lazy => 1,
    default => sub {
        my $self = shift;
        return sha1_hex($self->data);
    },
);

=head2 get_digest

Return the digest of the raw request which is defined as the sha1 hash over
the DER encoded "inner" request without the signature parts given in
hexadecimal format.

I<Note>: While an RSA request has a deterministic signature and creates
an overall identical binary each time you create a CSRs from the same
data the signature of an ECC request contains a random number so the "outer"
hash will change if a client recreates a CSRs.

=cut

has digest => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_digest',
    lazy => 1,
    default => sub {
        my $self = shift;
        return sha1_hex($self->_pkcs10()->certificationRequest());
    },
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my $data = shift;

    Crypt::PKCS10->setAPIversion(1);
    my $pkcs10 = Crypt::PKCS10->new( $data, ignoreNonBase64 => 1, verifySignature => 0);
    if (Crypt::PKCS10->error) {
        die Crypt::PKCS10->error;
    }

    return $class->$orig( data => $pkcs10->csrRequest(), _pkcs10 => $pkcs10 );

};


1;


__END__;

package OpenXPKI::Crypt::PKCS7::CertificateList;
use Moose;

use English;

use MIME::Base64;
use Digest::SHA qw(sha256);
use Convert::ASN1 ':tag';

use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypt::PKCS7;

=head1 NAME

OpenXPKI::Crypt::PKCS7::CertificateList

=head1 DESCRIPTION

Create a PKCS7 certificates-only structure from a list of certificates.

After adding the certificate to the I<certs> attribute call I<data> or
I<pem> to get the PKCS7 structure. The class does no checks or any
sorting on the list of items passed so make sure to sanitize your data.

=head1 PARAMETERS / ACCESSOR METHODS

=cut

has _asn1 => (
    is => 'ro',
    required => 1,
    isa => 'Convert::ASN1',
);

=head2 certs

An array ref holding the DER encoded certificates that will be part of
the final structure.

=cut

has certs => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    default => sub { return [] }
);

=head2 crls

An array ref holding the DER encoded CRLs that will be part of
the final structure. If not set, the tag is also not created,
can be an empty array ref to stay compatible to openssl crl2pkcs7
output where this is an empty tag.

=cut

has crls => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    lazy => 1,
    predicate => 'has_crls',
    default => sub { return [] }
);

=head2 keep_duplicates

The default is to not add a certificate more than once even if it occurs
multiple times in the input. Set to true if you explicitly want to keep
duplicates in the output structure.

=cut

has keep_duplicates => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);


=head2 data

The DER encoded PKCS7 structure.

=cut

has data => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '__build_pkcs7'
);

=head2 pem

The PEM encoded PKCS7 structure.

=cut

has pem => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $pem = encode_base64($self->data(), '');
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        chomp $pem;
        return "-----BEGIN PKCS7-----\n$pem\n-----END PKCS7-----";
    },
);

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;

    my $asn = Convert::ASN1->new( encoding => 'DER' );
    $asn->prepare( $OpenXPKI::Crypt::PKCS7::schema )
        or die( "Internal error in " . __PACKAGE__ . ": " . $asn->error );

    if (@_ == 1) {
        my $certs = shift;
        return $class->$orig(_asn1 => $asn, certs => $certs );
    }

    return $class->$orig( @_, _asn1 => $asn );

};

=head1 METHODS

=cut

sub __build_pkcs7 {

    my $self = shift;
    my $asn1 = $self->_asn1;
    my $parser = $asn1->find('PKCS7ContentInfoSignedData');

    # this is the "real" return payload - a degenerated PKCS7 container
    my $seen;
    sha256

    my @certs;
    if ($self->keep_duplicates()) {
        @certs = map { {'certificate' => $_ } } @{$self->certs};
    } else {
        foreach my $cert (@{$self->certs}) {
            my $id = sha256($cert);
            next if ($seen->{$id});
            $seen->{$id} = 1;
            push @certs, {'certificate' => $cert };
        }
    }

    OpenXPKI::Exception->throw(
        message => 'You must add the certificates to the certs attribute'
    ) unless (@certs);

    my $crls;
    if ($self->has_crls()) {
        $crls = $self->crls();
    }

    my $payload = $parser->encode({
        'contentType' => '1.2.840.113549.1.7.2', # signed data
        'content' => {
            'version' => 1,
            'contentInfo' => { 'contentType' => '1.2.840.113549.1.7.1' }, # id-data
            'digestAlgorithms' => {'daSet' => [] },
            'signerInfos' => { 'siSet' => [] },
            'certificates' => { 'certSet' => \@certs },
            # when undef, the tag is not created, with an empty list
            # it is an empty tag which is identical to the output of
            # todays convert_cert command (uses openssl crl2pkcs7).
            'crls' => $crls,
        }
    }) || die $parser->error;

    return $payload;

}

=head2 add_cert

Expects a DER or PEM encoded certificate as argument and appends it to
the list of certificates.

=cut

sub add_cert {

    my $self = shift;
    my $data = shift;

    if ($data =~ m{\A(?!\x06)-----BEGIN\ ([^-]+)-----\s*(.*)\s*-----END\ \1-----}xms) {
        ##! 8: 'PEM data - decoding'
        $data = decode_base64($2);
    }
    push @{$self->certs()}, $data;

}

__PACKAGE__->meta->make_immutable;

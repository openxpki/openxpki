package OpenXPKI::Crypt::PKCS10;
use OpenXPKI -class;

with 'OpenXPKI::Role::ASN1Parse';

use OpenXPKI::DN;
use OpenXPKI::Crypt::DN;
use Digest::SHA qw(sha1_base64 sha1_hex);
use OpenXPKI::DateTime;
use MIME::Base64;
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
        my $pem = encode_base64($self->data(), '');
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
        my $csr_subject = $self->_pkcs10()->subjectSequence();
        my $dn = OpenXPKI::Crypt::DN->new( sequence => $csr_subject );
        return $dn->get_subject();
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
        return uc join ':', ( unpack '(A2)*', sha1_hex( $self->get_pub_key() ) );
    }
);

=head2 get_pub_key

Return the public key from the request in binary format

=cut

has pub_key => (
    is => 'ro',
    required => 0,
    isa => 'Str',
    reader => 'get_pub_key',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->_pkcs10()->{certificationRequestInfo}{subjectPKInfo}{subjectPublicKey}[0];
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

=head2 subject_hash

Returns a hashref with the subject DN components, keys are uppercase RDN
shortnames (e.g. C<CN>, C<OU>), values are arrayrefs of values. Same format
as C<subject_hash> in L<OpenXPKI::Crypt::X509>.

=cut

has subject_hash => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    lazy => 1,
    default => sub {
        my $self = shift;
        my $seq = $self->_pkcs10->subjectSequence();
        return {} unless $seq;
        return OpenXPKI::Crypt::DN->new( sequence => $seq )->as_hash();
    }
);

=head2 get_subject_alt_name

Returns an arrayref of C<[$type, $value]> pairs for all SANs in the request.
Same format as C<get_subject_alt_name> in L<OpenXPKI::Crypt::X509>.

=cut

has subject_alt_name => (
    is => 'ro',
    init_arg => undef,
    isa => 'ArrayRef',
    reader => 'get_subject_alt_name',
    lazy => 1,
    builder => '_build_san',
);

=head2 get_cert_subject_parts

Returns the merged hashref of subject DN components and SAN entries (with
C<SAN_> prefix). Same format and semantics as C<get_cert_subject_parts> in
L<OpenXPKI::Crypt::X509>.

=cut

has cert_subject_parts => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    reader => 'get_cert_subject_parts',
    lazy => 1,
    builder => '_build_cert_subject_parts_hash',
);

=head2 get_custom_extension

Returns an arrayref of custom (Private Enterprise Number) extensions found in
the CSR. Each entry is a hashref with keys C<oid>, C<encoding>, and C<value>.

Only extensions with OIDs under C<1.3.6.1.4.1.> are returned.
B<NOTE>: Extensions known to C<Crypt::PKCS10> are excluded as they are mapped
to their verbose names, this applies mainly to the common Microsoft extensions

=cut

has custom_extension => (
    is => 'ro',
    init_arg => undef,
    isa => 'ArrayRef',
    reader => 'get_custom_extension',
    lazy => 1,
    builder => '_build_oid_ext',
);

=head2 get_cert_extension_parts

Returns the content of custom_extension as hashref with the oid beeing the
key of the hash and the original item beeing the value.

=cut

has cert_extension_parts => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    reader => 'get_cert_extension_parts',
    lazy => 1,
    default => sub {
        return { map {  ($_->{oid} => $_) } shift->get_custom_extension->@* };
    },
);

=head2 get_public_key_alg

Returns the normalized public key algorithm string: C<RSA>, C<EC>, or C<DSA>.
Same format as C<get_public_key_alg> in L<OpenXPKI::Crypt::X509>.

=cut

has public_key_alg => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_public_key_alg',
    lazy => 1,
    default => sub {
        my $alg = shift->_pkcs10->pkAlgorithm // '';
        return 'RSA' if $alg eq 'rsaEncryption';
        return 'EC'  if $alg eq 'ecPublicKey';
        return 'DSA' if $alg eq 'dsa';
        return 'unsupported';
    }
);

=head2 get_key_params

Returns a hashref with public key parameters: C<key_length> (bits) and for
EC keys also C<curve_name>.

=cut

has key_params => (
    is => 'ro',
    init_arg => undef,
    isa => 'HashRef',
    reader => 'get_key_params',
    lazy => 1,
    default => sub {
        my $kp = shift->_pkcs10->subjectPublicKeyParams();
        return { key_length => $kp->{keylen}, ($kp->{curve} ? (curve_name => $kp->{curve}) : ()) };
    }
);

=head2 get_signature_digest

Returns the digest algorithm from the signature, e.g. C<sha256>, C<sha1>.

=cut

has signature_digest => (
    is => 'ro',
    init_arg => undef,
    isa => 'Str',
    reader => 'get_signature_digest',
    lazy => 1,
    default => sub {
        my @t = shift->_pkcs10->signatureAlgorithm() =~ m{ (with-?(md5|sha\d+))|((md5|sha\d+)with) }ix;
        return lc($t[1] || $t[3] || 'unknown');
    }
);

=head2 check_signature

Returns true if the PKCS#10 signature is cryptographically valid.

=cut

sub cn { shift->subject_hash()->{CN}->[0] }

sub check_signature    { return shift->_pkcs10->checkSignature() }

=head2 get_extension_value (oid/name)

Return the value of the given request extension, undef if not exists.

=cut

sub get_extension_value {
    return shift->_pkcs10->extensionValue(shift)
}

=head2 get_attribute_value (oid/name)

Return the value of the given request attribute, undef if not exists.

=cut

sub get_attribute_value  {
    return shift->_pkcs10->attributes(shift)
}

sub _build_oid_ext {

    my $self = shift;

    my $attrs = $self->_pkcs10->_attributes;
    my $ext_list = $attrs->{extensionRequest} // [];

    my @oid_list;
    foreach my $oid_ext ($ext_list->@*) {
        # we are just interessted in PEN OIDs extensions
        # Note: Most of the MS extensions (PEN 311) are translated
        # to their names in the parser class and will not show up here :(
        # Walk through extensions and extract only the ones wit a PEN OID
        next unless (substr($oid_ext->{'extnID'},0,12) eq '1.3.6.1.4.1.');

        my $item = { oid => $oid_ext->{'extnID'} };

        my ($val, $tag) = decode_tag_as_string($oid_ext->{extnValue});
        if (defined $val && ref $val eq '') {
            $item->{encoding} = $tag;
            $item->{value} = $val;
        } else {
            # unable to parse - base64 encode what we got
            $item->{value} = encode_base64($oid_ext->{extnValue});
        }
        push @oid_list, $item;

    }
    return \@oid_list;
}


sub _build_san {

    my $self = shift;

    my $san_map = {
        rfc822Name               => 'email',
        dNSName                  => 'DNS',
        x400Address              => '',
        ediPartyName             => '',
        uniformResourceIdentifier => 'URI',
        iPAddress                => 'IP',
        registeredID             => 'RID',
    };

    my @san_list;
    for my $san ($self->_pkcs10->subjectAltName()) {
        my $san_type = $san_map->{$san};
        next unless $san_type;
        for my $value ($self->_pkcs10->subjectAltName($san)) {
            push @san_list, [ $san_type, $value ] if $value;
        }
    }
    return \@san_list;
}

sub _build_cert_subject_parts_hash {
    my $self = shift;
    my $hash = $self->subject_hash();
    for my $san ($self->get_subject_alt_name()->@*) {
        my ($type, $value) = $san->@*;
        $type = 'SAN_'.uc($type);
        $hash->{$type} = [] unless defined $hash->{$type};
        push @{$hash->{$type}}, $value;
    }
    return $hash;
}

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

__PACKAGE__->meta->make_immutable;

__END__;

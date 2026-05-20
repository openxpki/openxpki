package OpenXPKI::Crypt::PKCS10;
use OpenXPKI -class;

with 'OpenXPKI::Role::CertAndReqParser';

use Digest::SHA qw(sha1_hex);

# Name → OID for PKCS#9 attributes and MS CSR attributes (camelCase, lowercase first)
our %KNOWN_ATTR = (
    challengePassword       => '1.2.840.113549.1.9.7',
    unstructuredName        => '1.2.840.113549.1.9.2',
    unstructuredAddress     => '1.2.840.113549.1.9.8',
    certificateTemplate     => '1.3.6.1.4.1.311.21.7',
    certificateTemplateName => '1.3.6.1.4.1.311.20.2',
);

=head1 Name

OpenXPKI::Crypt::PKCS10

=head1 Description

Helper class to extract information from a PKCS10 request.

Expects PEM encoded data with headers or raw binary as single argument
to new.

=cut

sub _asn1_root_node { 'CertificationRequest' }
sub _pem_type       { 'CERTIFICATE REQUEST'  }

sub get_csr_identifier { shift->get_identifier() }

=head2 get_transaction_id

Return the transaction_id which is defined as the sha1 hash over
the DER encoded request in hexadecimal format.

=cut

has transaction_id => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'Str',
    reader   => 'get_transaction_id',
    lazy     => 1,
    default  => sub { sha1_hex(shift->data) },
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
    is       => 'ro',
    init_arg => undef,
    isa      => 'Str',
    reader   => 'get_digest',
    lazy     => 1,
    default  => sub { sha1_hex(shift->_tbs_der()) },
);

=head2 get_attribute_value (name_or_oid)

Returns the value of a CSR attribute. When called with a known name (e.g.
C<challengePassword>, C<clientInformation>), the ASN.1 value is decoded and
returned as a string or hashref. When called with an OID string, the raw
C<attrValues> ArrayRef (opaque DER bytes) is returned unchanged.

Returns C<undef> if the attribute is not present or the name is unknown.

=cut

sub get_attribute_value {
    my ($self, $name_or_oid) = @_;
    my $is_oid = ($name_or_oid =~ /^\d+(\.\d+)+$/);
    my $oid    = $is_oid ? $name_or_oid : ($KNOWN_ATTR{$name_or_oid} // return undef);

    my $attrs = $self->_parsed->{certificationRequestInfo}{attributes} // [];
    my $raw;
    for my $attr (@$attrs) {
        next unless $attr->{attrType} eq $oid;
        $raw = $attr->{attrValues};
        last;
    }
    return undef unless(defined $raw);
    return $is_oid ? $raw : $self->_decode_attr($oid, $raw);
}

__PACKAGE__->meta->make_immutable;

__END__;

package OpenXPKI::Role::IssuerSerial;

use Moose::Role;

use OpenXPKI::Crypt::DN;

=head2 iasn_from_hash

static helper method to convert a I<issuerAndSerialNumber> hash from
Convert::ASN1 to a perl hash. The resulting hash will have the keys
I<serial> with the serial in decimal notation as string and
I<issuer> pointing to a I<OpenXPKI::Crypt::DN>.

=cut

sub iasn_from_hash {

    my $hash = shift;

    my $sn = $hash->{serialNumber};
    # serial number is a scalar only for small numbers
    if (ref $sn eq 'Math::BigInt') {
        $sn = $sn->bstr();
    }

    my $dn = OpenXPKI::Crypt::DN->new( sequence => $hash->{issuer} );

    return {
        serial => $sn,
        issuer => $dn,
    };
}

1;
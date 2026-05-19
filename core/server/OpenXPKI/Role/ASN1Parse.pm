package OpenXPKI::Role::ASN1Parse;
use OpenXPKI -role;

use Convert::ASN1 ':tag';
use List::Util 'any';

our %tagmap = (
    'INTEGER'           => 2,
    'BIT STRING'        => 3,
    'OCTET STRING'      => 4,
    'NULL'              => 5,
    'OBJECT IDENTIFIER' => 6,
    'OID'               => 6,
    'UTF8String'        => 12,
    'SEQUENCE'          => 16,
    'SET'               => 17,
    'PrintableString'   => 19,
    'T61String'         => 20,
    'IA5String'         => 22,
    'UTCTime'           => 23,
);

our %tagmap_reverse = reverse %tagmap;

=head2 tag_class_to_string

Return the ASN1 litaral name for a tag number, e.g. 12 => UTF8String

=cut

sub tag_class_to_string {
    my $tag = shift;
    return $tagmap_reverse{$tag} ? $tagmap_reverse{$tag} : $tag;
}

sub decode_tag_as_string {

    my $raw = shift;
    my $asn1type = shift || 'DirectoryString';

    state $asn = Convert::ASN1->new;

    my $value;
    if (any { $_ eq $asn1type } qw(TeletexString PrintableString BMPString UniversalString UTF8String IA5String INTEGER)) {
        $asn->prepare("data $asn1type");
        # returns { data => <value> }
        my $data = $asn->decode($raw);
        return unless ($data);
        $value = $data->{data};
    } elsif ($asn1type eq 'DirectoryString') {

        $asn->prepare(q<
        DirectoryString ::= CHOICE {
        TeletexString   TeletexString,
        PrintableString PrintableString,
        BMPString       BMPString,
        UniversalString UniversalString,
        UTF8String      UTF8String,
        IA5String       IA5String,
        INTEGER         INTEGER }
        >);

        # returns { <asn1type> => <value> }
        my $data = $asn->decode($raw);
        return unless ($data);
        $asn1type = (keys $data->%*)[0];
        $value = $data->{$asn1type};
    }

    return unless(defined $value);

    return ($value, $asn1type);

}


=head2 decode_tag

Expects a raw buffer holding an ASN1 encoded value and tries to extract its
"scalar". This works for tags beeing some type of string/scalar but also for
nested structures which end in a single scalar.

Tags of type sequence or combined tags are not decoded and returned as is.

Nested constructed tags can not be decoded and cause the method to die.

Returns the raw buffer of the finally reached ASN1 value.

=cut

sub decode_tag {

    my $raw = shift;

    # return undef if we dont get any data
    return unless($raw);

    # the raw content starts with tag and length as bytes sequences
    # the length of each sequence is itself encoded in the first bit
    # tagbytes is the number of bytes that are used to encode the tag
    my ($tagbytes, $tag) = asn_decode_tag($raw);

    # length starts after the tag so we need to use tagbytes as offset
    my ($lengthbytes, $length) = asn_decode_length(substr($raw, $tagbytes));

    # offset at the head of the first segment
    my $offset = $tagbytes + $lengthbytes;

    # return directly if it this is not a constructed tag (Bit6 is set)
    # we are not interessted in the actual values of tag and length but
    # just strip the header of the raw buffer
    return substr($raw, $offset) unless ($tag & 0x20);
    # constructed mode means that the buffer contains multiple segments
    # where each one is an encoded tag with tag, length, value
    # [[tag, length][seg1][seg2][seg3]...
    $tag &= 0xDF;

    # inifinite length encoding - the value has two null bytes at the end
    # the proper size of the raw value is already handled by the asn1 parser
    # the while loop is a safety net, itag == 0 should be seen in any case
    $length = length($raw)-2 if ($length == -1);
    my $buffer;
    while ($offset < $length) {
        # read the tag header from the segment at offset
        my ($tagbytes, $itag) = asn_decode_tag(substr($raw, $offset));

        # the tag contains a constructed structure we do not want to parse
        # so we return the binary tag data without any conversions
        if (($itag & 0x20 && !$buffer)) {
            $buffer = $raw;
            last;
        }

        last if ($itag == 0);
        # The inner and outer tags must be the same - it might be possible
        # to have nested constructed tags but we dont want to support this now
        # tag == 128 is a context specific outer tag with no lower tag number
        die sprintf("Inner (%02d) and outer (%02d) tag do not match!?", $itag, $tag)
            unless($tag == 128 || $itag == $tag);

        # set offset to the right end of the tag header of the current segment
        $offset += $tagbytes;
        # ...and decode the length header of the segment
        my ($lengthbytes, $length) = asn_decode_length(substr($raw, $offset));
        # forward offset beyond the length header to the left end of the value
        $offset += $lengthbytes;

        # An infinite lenght should not be possible here but lets check it
        die "Infinite length found in constructed item" if ($length == -1);
        $buffer .= substr($raw, $offset, $length);
        $offset += $length;
    }
    return $buffer;
}

=head2 encode_tag

Takes a value and a class and encodes value as ASN1 tag. The class can
be any valid class number (integer) or a class name from the following
list. OIDs can be given as byte string or in dotted decimal notation.

=over

=item INTEGER

=item BIT STRING

=item OCTET STRING

=item NULL

=item OBJECT IDENTIFIER

=item UTF8String

=item SEQUENCE

=item SET

=item PrintableString

=item T61String

=item IA5String

=item UTCTime

=back

=cut

sub encode_tag {
    my $value = shift;
    my $class = shift || 4;

    if ($class !~ m{\A\d+\z}) {
        $class = $tagmap{$class} || die "Invalid class name given";
    }

    # object identifier in dottet decimal notation
    if ($class == 6 && $value =~ m{\A\d+\.}) {
        # this code is borrowed from Convert::BER
        my @data = ($value =~ /(\d+)/g);
        # the first two digits are combined into one character
        my $first = $data[1] + ($data[0] * 40);
        splice(@data,0,2,$first);
        # values >128 are encoded with variable length where each character
        # holds seven bits of value, the end of the digit is encoded with
        # the last character having MSB=0 and all others have MSB=1
        # Example: 840 = 110|1001000 =  10000110 + 01001000
        @data = map {
            my @d = ($_);
            if($_ >= 0x80) {
                @d = ();
                my $v = 0 | $_; # unsigned
                while($v) {
                unshift(@d, 0x80 | ($v & 0x7f));
                $v >>= 7;
                }
                $d[-1] &= 0x7f;
            }
            @d;
        } @data;
        $value = CORE::pack("C*", @data);
    }

    return asn_encode_tag($class).asn_encode_length(length($value)).$value;
}

1;

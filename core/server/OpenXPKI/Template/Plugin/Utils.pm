package OpenXPKI::Template::Plugin::Utils;

use Moose;
use MooseX::NonMoose;
extends 'Template::Plugin';

use JSON;
use Template::Plugin;
use MIME::Base64;
use Digest::SHA;
use Data::Dumper;
use OpenXPKI::DN;
use Crypt::PK::RSA;
use Crypt::PK::ECC;

=head1 OpenXPKI::Template::Plugin::Utils

Plugin for Template::Toolkit providing some string manipulation functions.

=cut

=head2 How to use

You need to load the plugin into your template before using it. As we do not
export the methods, you need to address them with the plugin name, e.g.

    [% USE Utils %]
    [% Utils.ascii_to_hex(value) %]

Will output the converted string.

=cut

has 'uuid_gen' => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { use Data::UUID; return Data::UUID->new(); }
);


# replicate behaviour of base class Template::Plugin: discard $context
around BUILDARGS => sub {
    my $orig = shift;
    my $class = shift;
    my $context = shift; # currently unused
    my $args = shift // {};

    return $class->$orig($args);
};

=head2 Methods

=head3 uuid

Generate a UUID v3 string (e.g. 4162F712-1DD2-11B2-B17E-C09EFE1DC403)

This is simply a wrapper around Data::UUID->gen_str.

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_gen()->create_str();
}

=head3 ascii_to_hex

Convert a ascii string to its hexadecimal representation, e.g. "OpenXPKI"
becomes 4f70656e58504b49.

=cut

sub ascii_to_hex {

    my $self = shift;
    my $string = shift;
    $string =~ s/(.)/sprintf("%02x",ord($1))/eg;
    return $string

}

=head3 to_base64 ( text )

Encode the given (binary) data using Base64 encoding, output is without
linebreaks or spaces.

=cut

sub to_base64 {

    my $self = shift;
    my $string = shift;
    return MIME::Base64::encode_base64($string, '');
}

=head3 to_base64url ( text )

Encode the given (binary) data using Base64 urlsafe encoding, output is
without linebreaks or spaces.

=cut

sub to_base64url {

    my $self = shift;
    my $string = shift;
    return MIME::Base64::encode_base64url($string, '');
}


=head3 sha256 ( text, secret )

Return the sha256 digest of the given input data in hexadecimal
representation. If the second argument is given it is used as secret
key to calculate sha256 HMAC instead of a plain digest.

=cut

sub sha256 {

    my $self = shift;
    my $string = shift;
    my $secret = shift;

    return Digest::SHA::sha256_hex($string) unless($secret);

    return Digest::SHA::hmac_sha256_hex($string);
}

=head3 digest ( text, encoding, digest )

Return the digest of the given input data in the choosen encoding.
The I<digest> parameter is passed to C<Digest::SHA>, default is sha1.

Supported encodings are I<base64url> (default), I<base64> and I<hex>
or I<binary>.

=cut

sub digest {

    my $self = shift;
    my $string = shift;
    my $encoding = shift || 'base64url';
    my $alg = shift || 'sha1';

    my $digest = Digest::SHA->new($alg);
    $digest->add($string);

    if ($encoding eq 'hex') {
        return $digest->hexdigest;
    } elsif ($encoding eq 'base64') {
        return $digest->b64digest;
    } elsif ($encoding eq 'base64url') {
        return MIME::Base64::encode_base64url($digest->digest,'');
    } elsif ($encoding eq 'binary') {
        return $digest->digest;
    } else {
        die "Invalid value given for encoding"
    }

}

=head3 pem_tidy ( text block with pem data )

Cleanup a string holding one or many PEM blocks by stripping any
surrounding text and reformatting the Base64 encoded payloads
into 64 characters per line.

Multiple PEM blocks are concatenated with a single newline character.

=cut

sub pem_tidy {

    my $self = shift;
    my $input = shift;

    my @blocks = $input =~ m{(-----BEGIN\ ([^-]+)-----)\s*([\w\/\+\=\s]+)\s*(-----END\ \2-----)}gxms;
    my @output;
    do {
        shift @blocks; # the BEGIN block
        my $separator = shift @blocks; # the separator word without the BEGIN word
        my $payload = decode_base64(shift @blocks) || die "Unable to decode PEM payload";
        shift @blocks; # END block

        my $pem = encode_base64($payload, '');
        $pem =~ s{ (.{64}) }{$1\n}xmsg;
        chomp $pem;
        push @output, "-----BEGIN $separator-----\n$pem\n-----END $separator-----";
    } while (@blocks);

    return join("\n", @output);
}

=head3 jwt_thumbprint ( key hash )

Expects a JWT key hash (as json string or hash structure) and returns
its thumbprint.

=cut

sub jwt_thumbprint {

    my $self = shift;
    my $key_hash = shift;

    return unless($key_hash);
    $key_hash = decode_json($key_hash) unless (ref $key_hash);

    if ($key_hash->{kty} eq 'RSA') {
        return Crypt::PK::RSA->new($key_hash)->export_key_jwk_thumbprint();
    }

    if ($key_hash->{kty} eq 'EC') {
        return Crypt::PK::ECC->new($key_hash)->export_key_jwk_thumbprint();
    }

    return;

}

=head2 dn ( subject, component )

Provides the same functionality as Certificate.dn but expects the
subject DN to parse as string in the first argument.

Returns the DN as parsed hash, if second parameter is given returns
the named part as string. Note: In case the named property has more
than one item, only the first one is returned!

=cut

sub dn {
    my $self = shift;
    my $subject = shift;
    my $component = shift;

    my %dn = OpenXPKI::DN->new( $subject )->get_hashed_content();

    if (!$component) {
        return \%dn;
    }

    if (!$dn{$component}) {
        return;
    }

    return $dn{$component}->[0];

}

__PACKAGE__->meta->make_immutable;

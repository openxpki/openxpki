package OpenXPKI::Template::Plugin::Utils;

use strict;
use warnings;
use utf8;

use Moose;
use Net::DNS;
use Template::Plugin;
use MIME::Base64;
use Data::Dumper;

extends 'Template::Plugin';


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

1;
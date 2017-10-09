# OpenXPKI::Serialization::Simple
#
# Written 2012 by Oliver Welter for the OpenXPKI project
# Copyright (C) 2012 by The OpenXPKI Project
#
#
=head1 NAME

OpenXPKI::Serialization::Simple

=cut

package OpenXPKI::Serialization::Simple;

use strict;
use warnings;
use English;
use Moose;

use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Serialization::JSON;
use OpenXPKI::Serialization::Legacy;
use MIME::Base64;

has 'BACKEND' => (
    is => 'ro',
    isa => 'Str',
    required => 0,
    default => 'JSON'
);

has '_json' => (
    is => 'ro',
    isa => 'Object',
    builder => '_init_json',
);

has '_legacy' => (
    is => 'ro',
    isa => 'Object',
    builder => '_init_legacy',
);

sub _init_json {
    my $self = shift;
    return OpenXPKI::Serialization::JSON->new();
}

sub _init_legacy {
    my $self = shift;
    return OpenXPKI::Serialization::Legacy->new();
}


sub serialize
{
    my $self = shift;
    my $args = shift;

    # undef is handled by the serialization layer as empty string
    if (!defined $args) {
        return "OXJSF1:";

    # using json to transmit binary data is very inefficient so we try to
    # detect binary data and decode this as base64
    } elsif (!ref $args && $args =~ m{[\x00-\x09]}s) {
        ##! 8: 'Found binary data - do base64'
        return "OXB64:" . encode_base64( $args );
    } else {
        return "OXJSF1:" . $self->_json()->serialize( $args );
    }
}


sub deserialize
{
    my $self = shift;
    my $string = shift;

    # Catch situations where the value is already deserialized, this can
    # happens when the workflow context is handed over via memory
    if ($string && (ref $string eq 'HASH') || (ref $string eq 'ARRAY')) {
        return $string;

    # We try to detect the serialization format autmagically here
    # The legacy encoder has one of these keywords and a separator

    } elsif ( $string =~ /^(SCALAR|ARRAY|HASH|UNDEF|BASE64)(\w|\n|-)/ ) {
        ##! 32: 'Autodetect - Legacy'
        my $separator = $2;
        # I dont know if there is anything else in the wild but just in case
        # we try to also detect non LF separators
        if ($separator ne "\n") {
            ##! 32: 'Non LF Separator ' . $separator
        }

        $self->_legacy()->{SEPARATOR} = $separator;
        return $self->_legacy()->deserialize( $string );

    } elsif ( $string =~ /^OXJSF1:/ ) {
        ##! 32: 'Autodetect - JSON'
        return $self->_json()->deserialize( substr($string,7) );
    } elsif ( $string =~ /^OXB64:/ ) {
        return decode_base64( substr($string, 6 ) );
    }

    OpenXPKI::Exception->throw(
        message => 'I18N_OPENXPKI_SERIALIZATION_SIMPLE_READ_DATA_TYPE_NOT_SUPPORTED',
        params => {
            DATA => substr( $string, 0, 10 )
        }
    );


}

# this is static!
sub is_serialized {

    my $msg  = shift;
    return (defined $msg &&
        ref $msg eq '' &&
        $msg =~ /^(SCALAR|BASE64|ARRAY|HASH|UNDEF|OXJSF1|OXB64)/);

}

1;

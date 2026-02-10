package OpenXPKI::Serialization::Simple;
use OpenXPKI -class;

=head1 NAME

OpenXPKI::Serialization::Simple

=cut

use OpenXPKI::Serialization::JSON;
use OpenXPKI::Serialization::Legacy;
use MIME::Base64;

has '_json' => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    builder => '_init_json',
);

has '_legacy' => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
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
        return "OXB64:" . encode_base64( $args, '' );
    } else {
        return "OXJSF1:" . $self->_json()->serialize( $args );
    }
}


sub deserialize
{
    my $self = shift;
    my $string = shift;

    if (!defined $string || $string eq '') {
        return undef;
    }

    # Catch situations where the value is already deserialized, this can
    # happens when the workflow context is handed over via memory
    if ($string && (ref $string eq 'HASH') || (ref $string eq 'ARRAY')) {
        return $string;

    } elsif ( $string =~ /^OXJSF1:/ ) {
        ##! 32: 'Autodetect - JSON'
        return $self->_json()->deserialize( substr($string,7) );
    } elsif ( $string =~ /^OXB64:/ ) {
        return decode_base64( substr($string, 6 ) );

    # The legacy encoder has one of these keywords and a separator
    # non-linebreak character as separator is no longer detected here
    # UNCOMMENT LINES BELOW FOR LEGACY SUPPORT
    #} elsif ( $string =~ /^(SCALAR|ARRAY|HASH|UNDEF|BASE64)\n/ ) {
    #    return $self->_legacy()->deserialize( $string );

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

    return 0 unless(defined $msg);

    return 0 unless(ref $msg eq '');

    return 1 if ($msg =~ /^(OXJSF1|OXB64)/);

    # UNCOMMENT LINE BELOW FOR LEGACY SUPPORT
    # return 1 if ($msg =~ /^((SCALAR|ARRAY|HASH|UNDEF|BASE64)\n)/);

    return 0;

}

__PACKAGE__->meta->make_immutable;

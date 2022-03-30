package OpenXPKI::Serialization::JSON;

use strict;
use warnings;

use JSON;
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use English;
use Log::Log4perl;
use Data::Dumper;

sub new
{

    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};

    bless $self, $class;

    my $keys = shift;

    $self->{JSON} = JSON->new(%{$keys})->allow_nonref;
    return unless defined $self->{JSON};

    return $self;
}

sub serialize
{
    my $self = shift;
    my $args = shift;

    if (!defined $args) {
        ##! 32: 'No args defined'
        return undef;
    }

    if ( ref $args !~ /(|ARRAY|HASH|SCALAR)/) {
        if ( "$args" ne '' ) {
            # stringified object
            # TODO - do we want this to rather throw an exception and clean
            # up the code that calls the serialization not to use any objects?
            ##! 1: 'implicit stringification of ' . ref $data . ' object'
            $args = "$args";
            Log::Log4perl->get_logger('openxpki.deprecated')->error('Stringification in serializer! ' . substr($args, 0, 50));
        } else {
            ##! 64: $args
            Log::Log4perl->get_logger('openxpki.system')->fatal('Found non-stringifiable object ' . ref $args);
            OpenXPKI::Exception->throw( message => 'Unable to serialize non-stringifiable object' );
        }
    }

    my $json;
    eval { $json = $self->{JSON}->encode( $args ); };
    if (!$json) {
        ##! 16: 'Unable to encode to json'
        ##! 64: $args
        Log::Log4perl->get_logger('openxpki.system')->fatal('Unable to serialize ' . ref $args);
        Log::Log4perl->get_logger('openxpki.system')->debug( Dumper $args );
        OpenXPKI::Exception->throw( message => 'Unable to serialize' );
    }
    return $json;

}


sub deserialize
{
    my $self = shift;
    my $string = shift;

    if (!$string) {
        return undef;
    }

    return $self->{JSON}->decode( $string );

}

1;
__END__

=head1 Name

OpenXPKI::Serialization::Simple

=head1 Description

Implements JSON Serialization.

=head1 Functions

=head2 new

If JSON is unavailable the constructor returns undef. Otherwise a
JSON Serialization object is returned.

See perldoc JSON.

=head2 serialize

See perldoc JSON.

=head2 deserialize

See perldoc JSON.

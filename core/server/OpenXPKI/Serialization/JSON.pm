# OpenXPKI::Serialization::Simple.pm
# Written 2006 by Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Serialization::JSON;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use JSON -convert_blessed_universally;
use OpenXPKI::Exception;
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

    $self->{JSON} = new JSON(%{$keys});
    $self->{JSON}->allow_nonref;
    return unless defined $self->{JSON};

    return $self;
}

sub serialize
{
    my $self = shift;
    my $args = shift;

    if (!defined $args) {
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
            Log::Log4perl->get_logger('openxpki.system')->fatal('Found non-stringifiable object ' . ref $args);
        }
    }

    my $json;
    eval { $json = $self->{JSON}->encode( $args ); };
    if (!$json) {
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

# OpenXPKI::Serialization::Fast
# Written 2008 by Alexander Klink for the OpenXPKI project
# (C) Copyright 2008 by The OpenXPKI Project

package OpenXPKI::Serialization::Fast;

use strict;
use warnings;

use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Serializer;

sub new {
    my $that = shift;
    my $class = ref($that) || $that;

    my $self = {
    };

    $Storable::canonical = 1;

    $self->{DS} = Data::Serializer->new(
        serializer => 'Storable',
        portable   => '1',
        encoding   => 'b64',
    );
    bless $self, $class;

    return $self;
}

sub serialize {
    my $self = shift;
    my $data = shift;

    return $self->{DS}->serialize([ $data ]);
}

sub deserialize {
    my $self = shift;
    my $msg  = shift;
#    Encode::_utf8_off($msg);

    my $content = $self->{DS}->deserialize($msg);
    if (ref $content ne 'ARRAY') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERIALIZATION_FAST_DESERIALIZE_INCORRECT_SERIALIZATION_FORMAT',
        );
    }
    return $content->[0];
}

1;
__END__

=head1 Name

OpenXPKI::Serialization::Fast

=head1 Description

A much faster serialization using Data::Serializer.

=head1 Functions

=head2 new

Initializes the object.

=head2 serialize

Returns the serialization of data passed as argument.

=head2 deserialize

Returns the deserialization of data passed as argument.

# OpenXPKI::Serialization::Simple.pm
# Written 2006 by Martin Bartosch for the OpenXPKI project
# (C) Copyright 2006 by The OpenXPKI Project

use strict;
use warnings;

package OpenXPKI::Serialization::JSON;

use OpenXPKI::VERSION;
our $VERSION = $OpenXPKI::VERSION::VERSION;

use OpenXPKI::Exception;
use English;

sub new
{
    eval { 
	require JSON;
	import JSON;
    };
    return if ($EVAL_ERROR);

    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};

    bless $self, $class;

    my $keys = shift;

    $self->{JSON} = new JSON(%{$keys});
    return unless defined $self->{JSON};

    return $self;
}

sub serialize
{
    my $self = shift;

    return $self->{JSON}->objToJson(shift);
}


sub deserialize
{
    my $self = shift;
    
    return $self->{JSON}->jsonToObj(shift);
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

package OpenXPKI::Template::Plugin::Utils;

use strict;
use warnings;
use utf8;

use Moose;
use Net::DNS;
use Template::Plugin;

use Data::Dumper;

extends 'Template::Plugin';

has 'uuid_gen' => (
    is => 'ro',
    isa => 'Object',
    lazy => 1,
    default => sub { use Data::UUID; return Data::UUID->new(); }
);

sub uuid {
    my $self = shift;
    return $self->uuid_gen()->create_str();
}


1;
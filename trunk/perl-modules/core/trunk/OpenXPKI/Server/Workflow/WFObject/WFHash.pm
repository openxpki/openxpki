# OpenXPKI::Server::Workflow::WFObject::WFHash
# Written by Scott Hardin for the OpenXPKI Project 2010
# Copyright (c) 2010 by the OpenXPKI Project

package OpenXPKI::Server::Workflow::WFObject::WFHash;

use strict;
use base qw( OpenXPKI::Server::Workflow::WFObject );
use Carp qw( confess );

# Storage for object attributes
my %workflow : ATTR( name => 'workflow' );
my %context_key : ATTR( name => 'context_key' );

#my %need_update : ATTR;
#my %serializer : ATTR;
#my %data_ref : ATTR;

# Handle initialization of objects of this class
sub BUILD {
    my ( $self, $id, $args ) = @_;
}

sub setValueForKey {
    my ($self, $key, $val) = @_;

    my $data = $self->_get_data_ref;

    if ( not defined $data ) {
        $data = $self->_set_data_ref( {} );
    } elsif ( ref($data) ne 'HASH' ) {
        confess "data in ", $context_key{ $self->ident }, " is not HASH";
    }

    $data->{$key} = $val;
    $self->write;
}

sub valueForKey {
    my ($self, $key) = @_;

    my $data = $self->_get_data_ref;

    if ( not defined $data ) {
        # if hash is empty, just return an empty string
        return '';
    } elsif ( ref($data) ne 'HASH' ) {
        confess "data in ", $context_key{ $self->ident }, " is not HASH";
    }

    return $data->{$key};
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::WFObject::WFHash

=head1 DESCRIPTION

WFHash is used to manage a hash data structure that is stored in a
workflow context parameter. It inherits from WFObject.

See L<OpenXPKI::Server::Workflow::WFObject> for details on the default
accessors and additional properties.

=head1 SYNOPSIS

  my $queue = OpenXPKI::Server::Workflow::WFObject::WFHash->new(
    { workflow => $workflow,
    context_key => 'my_queue' } );

  print "my queue contains ", $queue->count, " element(s).\n";

=head1 METHODS

=head2 setValueForKey KEY VALUE

Associates the VALUE with the given KEY.

=head2 valueForKey KEY

Returns the element associated with the given KEY.



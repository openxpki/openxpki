# OpenXPKI::Server::Workflow::WFObject::WFArray
# Written by Scott Hardin for the OpenXPKI Project 2010
# Copyright (c) 2010 by the OpenXPKI Project

package OpenXPKI::Server::Workflow::WFObject::WFArray;

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

sub pop {
    my ($self) = @_;
    my $data = $self->_get_data_ref;
#    my $data = $data_ref{ ident $self };
    
    if ( defined $data ) {
        if ( ref($data) eq 'ARRAY' ) {
#            $self->_will_need_update;
            my $ret = CORE::pop @{$data};
            $self->write;
            return $ret;
        }
        else {
            confess "data in ", $context_key{ $self->ident }, " is not ARRAY";
        }
    }
    else { # if array appears to be empty, just return an empty string
        return '';
    }
}

sub shift {
    my ($self) = @_;
    my $data = $self->_get_data_ref;
#    my $data = $data_ref{ ident $self };
    if ( defined $data ) {
        if ( ref($data) eq 'ARRAY' ) {
#            $self->_will_need_update;
            my $ret = CORE::shift @{$data};
            $self->write;
            return $ret;
        }
        else {
            confess "data in ", $context_key{ $self->ident }, " is not ARRAY";
        }
    }
    else { # if array appears to be empty, just return an empty string
        return '';
    }
}

sub push {
    my $self = CORE::shift;
    my $data = $self->_get_data_ref;
#    my $data = $data_ref{ ident $self };

    if ( not defined $data ) {
        $data = $self->_set_data_ref( [] );
    }
    if ( ref($data) eq 'ARRAY' ) {
        $self->_will_need_update;
        CORE::push @{$data}, @_;
            $self->write;
#            return $ret;
    }
    else {
        confess "data in ", $context_key{ $self->ident }, " is not ARRAY";
    }
}

sub unshift {
    my $self = CORE::shift;
    my $data = $self->_get_data_ref;
#    my $data = $data_ref{ ident $self };

    if ( not defined $data ) {
        $data = $self->_set_data_ref( [] );
    }
    if ( ref($data) eq 'ARRAY' ) {
        $self->_will_need_update;
        CORE::unshift @{$data}, @_;
            $self->write;
#            return $ret;
    }
    else {
        confess "data in ", $context_key{ $self->ident }, " is not ARRAY";
    }
}

sub count {
    my ($self) = @_;
    my $data = $self->_get_data_ref;
#    my $data = $data_ref{ ident $self };
    
    if ( defined $data ) {
        if ( ref($data) eq 'ARRAY' ) {
#            $self->_will_need_update;
            return scalar @{$data};
        }
        else {
            confess "data in ", $context_key{ $self->ident }, " is not ARRAY";
        }
    }
    else { # if array appears to be empty, just return 0
        return 0;
    }
}

sub value {
    my ($self, $index) = @_;
    my $data = $self->_get_data_ref;
#    my $data = $data_ref{ ident $self };
    
    if ( defined $data ) {
        if ( ref($data) eq 'ARRAY' ) {
#            $self->_will_need_update;
	    if (defined $index) {
		return $data->[$index];
	    } else {
		return $data;
	    }
        }
        else {
            confess "data in ", $self->get_context_key, " is not ARRAY";
        }
    }
    else { # if array appears to be empty, just return an empty string/array
    	if (defined $index) {
    	    return '';
    	} else {
    	    return [];
    	}
    }
}


sub values {
    my ($self) = @_;
    my $data = $self->_get_data_ref;
#    my $data = $data_ref{ ident $self };
    
    if ( defined $data ) {
        if ( ref($data) eq 'ARRAY' ) {
#            $self->_will_need_update;
            return [ @{ $data } ];
        }
        else {
            confess "data in ", $self->get_context_key, " is not ARRAY";
        }
    }
    else { # if array appears to be empty, just return an empty array
        return [];
    }
}

1;

__END__

=head1 NAME

OpenXPKI::Server::Workflow::WFObject::WFArray

=head1 DESCRIPTION

WFArray is used to manage an array data structure that is stored in a
workflow context parameter. It inherits from WFObject.

The two primitive methods--count and value--provide the basis for all
other methods in its interface.

See L<OpenXPKI::Server::Workflow::WFObject> for details on the default
accessors and additional properties.

=head1 SYNOPSIS

  my $queue = OpenXPKI::Server::Workflow::WFObject::WFArray->new(
    { workflow => $workflow,
    context_key => 'my_queue' } );

  print "my queue contains ", $queue->count, " element(s).\n";

=head1 METHODS

=head2 count

Returns the number of elements stored in the array. If the array is not 
initialized, 0 is returned.

=head2 value INDEX

Returns the element stored at the given INDEX.

If INDEX is not specified or undefined the method returns the complete
array as a reference.

=head2 values

Returns a reference to a copy of the array stored in the instance. 

=head2 pop, shift

Removes an element from the array, returning its value to the caller.
For I<pop>, the element from the end of the array is removed and for
I<shift>, the element from the beginning is removed.

=head2 push, unshift



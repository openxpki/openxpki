package OpenXPKI::Connector::WorkflowContext;

use strict;
use warnings;
use English;
use Moose;
use DateTime;
use Data::Dumper;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;

extends 'Connector';

our $CONTEXT = {};

has key => (
    is  => 'ro',
    isa => 'Str',
);

has value => (
    is  => 'rw',
    isa => 'HashRef|Str',
);

has encrypt => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

sub set_context {
   $CONTEXT = shift;
}

sub BUILD {

    my $self = shift;
    $self->log()->trace('context is '. Dumper $CONTEXT );

}

sub get {

    my $self = shift;

    my $val = $self->_get_node();

    if (defined $val && ref $val ne '') {
        die "requested value is not a scalar " . Dumper $val;
    }

    return $val;

}

sub get_hash {

    my $self = shift;

    my $val = $self->_get_node();

    if (defined $val && ref $val ne 'HASH') {
        die "requested value is not a HASH " . Dumper $val;
    }

    return $val;

}


sub get_list {

    my $self = shift;

    my $val = $self->_get_node();

    if (defined $val && ref $val ne 'ARRAY') {
        die "requested value is not a list " . Dumper $val;
    }

    return $val ? @{$val} : undef;

}

sub _get_node {

    my $self = shift;

    my $key = $self->LOCATION();

    $self->log()->debug('Get context value for '.$key );

    my $val = $CONTEXT->{$key};

    return $self->_node_not_exists() unless (defined $val);

    if (ref $val eq '' && OpenXPKI::Serialization::Simple::is_serialized($val)) {
        my $ser  = OpenXPKI::Serialization::Simple->new();
        $val = $ser->deserialize( $val );
    }

    $self->log()->error('value is '. Dumper $val );

    return $val;
}

1;

__END__;


=head1 NAME

OpenXPKI::Connector::WorkflowContext;

=head1 DESCRIPTION

Connector to interact with the workflow context, the LOCATION is used
as the context key. The path is not evaluated and ignored.

The content of the context must be set into the global/static class
variable using the static method set_context.

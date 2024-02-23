package OpenXPKI::Connector::WorkflowContext;

use Moose;
extends 'Connector';

use English;
use DateTime;
use Data::Dumper;
use OpenXPKI::DateTime;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;

our $CONTEXT = {};

has key => (
    is  => 'ro',
    isa => 'Str',
);

sub set_context {
   $CONTEXT = shift;
}

sub BUILD {

    my $self = shift;
    $self->log->trace('context is '. Dumper $CONTEXT ) if $self->log->is_trace;

}

sub get {

    my $self = shift;

    my $val = $self->_get_node();

    if (!defined $val) {
        return $self->_node_not_exists();
    }

    if (ref $val eq 'HASH' && $self->key()) {
        $val = $val->{$self->key()};
        if (!defined $val) {
            return $self->_node_not_exists();
        }
    }

    if (ref $val ne '') {
        $self->log->error('requested value is not a scalar');
        die "requested value is not a scalar " . Dumper $val;
    }

    return $val;

}

sub get_hash {

    my $self = shift;

    my $val = $self->_get_node();

    if (defined $val && ref $val ne 'HASH') {
        $self->log->error('requested value is not a hash');
        die "requested value is not a HASH " . Dumper $val;
    }

    return $val;

}


sub get_list {

    my $self = shift;

    my $val = $self->_get_node();

    if (defined $val && ref $val ne 'ARRAY') {
        $self->log->error('requested value is not a list');
        die "requested value is not a list " . Dumper $val;
    }

    return $val ? @{$val} : undef;

}

sub _get_node {

    my $self = shift;

    my $key = $self->LOCATION();

    $self->log->debug('Get context value for '.$key );

    my $val = $CONTEXT->{$key};

    return $self->_node_not_exists() unless (defined $val);

    if (ref $val eq '' && OpenXPKI::Serialization::Simple::is_serialized($val)) {
        my $ser  = OpenXPKI::Serialization::Simple->new();
        $val = $ser->deserialize( $val );
    }

    $self->log->trace('Value is '. Dumper $val ) if $self->log->is_trace;

    return $val;
}

__PACKAGE__->meta->make_immutable;

__END__;


=head1 NAME

OpenXPKI::Connector::WorkflowContext;

=head1 DESCRIPTION

Connector to interact with the workflow context, the LOCATION is used
as the context key. The path is not evaluated and ignored.

The content of the context must be set into the global/static class
variable using the static method set_context.

=head2 Parameters

=over

=item key

Return a single key from the HASH inside the context value at LOCATION.

=back

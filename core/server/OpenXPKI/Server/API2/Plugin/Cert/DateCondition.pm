package OpenXPKI::Server::API2::Plugin::Cert::DateCondition;
use Moose;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::DateCondition

Used to assemble an SQL WHERE condition regarding dates that assures the
strictest date range is used.

=cut

has '_smaller_than' => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_smaller_than',
);

has '_greater_than' => (
    is => 'rw',
    isa => 'Int',
    predicate => 'has_greater_than',
);


sub smaller_than {
    my ($self, $value) = @_;
    if (!$self->has_smaller_than or $self->_smaller_than > $value) {
        $self->_smaller_than($value);
    }
}

sub greater_than {
    my ($self, $value) = @_;
    if (!$self->has_greater_than or $self->_greater_than < $value) {
        $self->_greater_than($value);
    }
}

sub between {
    my ($self, $lower, $upper) = @_;
    $self->greater_than($lower);
    $self->smaller_than($upper);
}

# Returns the SQL WHERE condition
sub spec {
    my ($self) = @_;

    if ($self->has_smaller_than and $self->has_greater_than) {
        return { -between => [ $self->_greater_than, $self->_smaller_than ] };
    }
    elsif ($self->has_smaller_than) {
        return { '<', $self->_smaller_than };
    }
    elsif ($self->has_greater_than) {
        return { '>', $self->_greater_than };
    }
    else {
        return;
    }
}

__PACKAGE__->meta->make_immutable;

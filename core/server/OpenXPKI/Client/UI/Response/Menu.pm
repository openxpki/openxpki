package OpenXPKI::Client::UI::Response::Menu;
use OpenXPKI::Client::UI::Response::DTO;

has 'items' => (
    is => 'rw',
    isa => 'ArrayRef[HashRef]',
    traits => ['Array'],
    handles => {
        _add_item => 'push',
        _no_item => 'is_empty',
    },
    default => sub { [] }, # without default 'is_empty' would fail if no value has been set yet
    documentation => 'ROOT',
);


# overrides OpenXPKI::Client::UI::Response::DTORole->is_set()
sub is_set { ! shift->_no_item }

sub add_item {
    my $self = shift;
    $self->_add_item(@_);
    return $self; # allows for method chaining
}

__PACKAGE__->meta->make_immutable;

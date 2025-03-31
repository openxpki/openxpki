package OpenXPKI::Client::Service::WebUI::Response::Menu;
use OpenXPKI -dto;

# Project modules
use OpenXPKI::Client::Service::WebUI::Response::Menu::Item;

has '_items' => (
    is => 'rw',
    isa => 'ArrayRef[OpenXPKI::Client::Service::WebUI::Response::Menu::Item]',
    traits => ['Array'],
    handles => {
        _add_item => 'push',
        _no_item => 'is_empty',
    },
    default => sub { [] }, # without default 'is_empty' would fail if no value has been set yet
    documentation => 'ROOT',
);


# overrides OpenXPKI::Client::Service::WebUI::Response::DTORole->is_set()
sub is_set ($self) { not $self->_no_item }

signature_for items => (
    method => 1,
    positional => [ 'ArrayRef[HashRef]' ],
);
sub items ($self, $items) {
    $self->add_item($_) for $items->@*;
}

signature_for add_item => (
    method => 1,
    positional => [ 'HashRef' ],
);
sub add_item ($self, $attrs) {
    my $i = OpenXPKI::Client::Service::WebUI::Response::Menu::Item->new($attrs->%*);
    $self->_add_item($i);
    return $self; # allows for method chaining
}

__PACKAGE__->meta->make_immutable;

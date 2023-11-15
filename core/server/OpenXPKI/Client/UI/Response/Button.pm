package OpenXPKI::Client::UI::Response::Button;
use OpenXPKI::Client::UI::Response::DTO;

has 'label' => (
    is => 'rw',
    isa => 'Str|Undef',
);

has 'format' => (
    is => 'rw',
    isa => 'Str|Undef',
);

has 'disabled' => (
    is => 'rw',
    isa => 'Bool',
);

has 'confirm' => (
    is => 'rw',
    isa => 'HashRef', # { label: '', description: '', confirm_label: '', cancel_label: '' }
);

has 'target' => (
    is => 'rw',
    isa => 'Str',
);

has 'href' => (
    is => 'rw',
    isa => 'Str',
);

has 'action' => (
    is => 'rw',
    isa => 'Str',
);

has 'action_params' => (
    is => 'rw',
    isa => 'HashRef',
);

has 'page' => (
    is => 'rw',
    isa => 'Str',
);

__PACKAGE__->meta->make_immutable;

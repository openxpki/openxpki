package OpenXPKI::Client::UI::Response::Section::Form;
use OpenXPKI::Client::UI::Response::DTO;

with 'OpenXPKI::Client::UI::Response::SectionRole';

has 'action' => (
    is => 'rw',
    isa => 'Str',
);

has 'reset' => (
    is => 'rw',
    isa => 'Str',
);

has 'submit_label' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has 'reset_label' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has '_fields' => (
    is => 'rw',
    isa => 'ArrayRef',
    traits => [ 'Array' ],
    handles => {
        _add_field => 'push',
    },
    documentation => 'content/fields',
);

sub BUILD {
    my $self = shift;
    $self->type('form');
}

sub add_field {
    my $self = shift;
    $self->_add_field(scalar @_ == 1 ? $_[0] : { @_ });
    return $self; # allows method chaining
}

__PACKAGE__->meta->make_immutable;

package OpenXPKI::DTO::ValidationException;

use Moose;
use OpenXPKI::DTO::Field;

has 'field' => (
    is => 'ro',
    isa => 'OpenXPKI::DTO::Field',
    required => 1,
);

has 'reason' => (
    is => 'ro',
    isa => 'Str', # Enum
    required => 1,
);

has 'message' => (
    is => 'rw',
    isa => 'Str', # Enum
    required => 0,
    lazy => 1,
    builder => '_build_hint',
);

has 'choices' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    required => 0,
    predicate => 'has_choices',
);

sub _build_hint {

    my $self = shift;

    my $name = $self->field()->name();
    if ($self->has_choices) {
        return "Value for *$name* must be one of\n". join("\n", @{$self->choices} );
    }

    if ($self->reason eq 'required') {
        return "The parameter *$name* is required.";
    }

    if ($self->reason eq 'type') {
        return "The value for parameter *$name* does not match the expected type/pattern.";
    }

    return "The value for parameter *$name* is not accepted."
}

__PACKAGE__->meta->make_immutable;

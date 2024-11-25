package OpenXPKI::DTO::ValidationException;
use OpenXPKI -class;

# TODO - merge with OpenXPKI::Exception

use OpenXPKI::Client::API::Util;

has 'field' => (
    is => 'ro',
    isa => 'Str',
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
    builder => '_build_message',
);

has 'choices' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    required => 0,
    predicate => 'has_choices',
);

sub _build_message {

    my $self = shift;

    my $name = OpenXPKI::Client::API::Util::to_cli_field($self->field);

    if ($self->has_choices) {
        return "Value for *$name* must be one of\n  ". join("\n  ", @{$self->choices} );
    }

    if ($self->reason eq 'required') {
        return "The parameter *$name* is required.";
    }

    if ($self->reason eq 'type') {
        return "The value for parameter *$name* does not match the expected type/pattern.";
    }

    if ($self->reason eq 'value') {
        return "The value for parameter *$name* can not be resolved.";
    }

    return "The value for parameter *$name* is not accepted."
}

__PACKAGE__->meta->make_immutable;

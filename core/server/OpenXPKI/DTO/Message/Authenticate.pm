package OpenXPKI::DTO::Message::Authenticate;

use Moose;
with 'OpenXPKI::DTO::Message';

has realm => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has stack => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    predicate => 'has_stack',
);

# use params to pass credentials

1;
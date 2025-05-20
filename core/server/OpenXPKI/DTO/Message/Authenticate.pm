package OpenXPKI::DTO::Message::Authenticate;
use OpenXPKI -class;

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

__PACKAGE__->meta->make_immutable;

package OpenXPKI::DTO::Message::ErrorResponse;
use OpenXPKI -class;

with 'OpenXPKI::DTO::Message';

has error_code => (
    is => 'ro',
    isa => 'Int',
    required => 0,
);

has message => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

__PACKAGE__->meta->make_immutable;

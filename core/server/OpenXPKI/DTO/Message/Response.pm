package OpenXPKI::DTO::Message::Response;

use Moose;
with 'OpenXPKI::DTO::Message';

has result => (
    is => 'ro',
    isa => 'Item|Undef',
    lazy => 1,
    default => sub { shift->params()->{result} }
);

1;

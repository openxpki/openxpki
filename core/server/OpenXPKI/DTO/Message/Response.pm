package OpenXPKI::DTO::Message::Response;
use OpenXPKI -class;

with 'OpenXPKI::DTO::Message';

has result => (
    is => 'ro',
    isa => 'Item|Undef',
    lazy => 1,
    default => sub { shift->params()->{result} }
);

__PACKAGE__->meta->make_immutable;

package OpenXPKI::DTO::Field::Int;

use Moose;
with 'OpenXPKI::DTO::Field';

has '+value' => (
    isa => 'Int'
);

__PACKAGE__->meta->make_immutable;

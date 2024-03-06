package OpenXPKI::DTO::Field::String;

use Moose;
with 'OpenXPKI::DTO::Field';

has '+value' => (
    isa => 'Str'
);

1;
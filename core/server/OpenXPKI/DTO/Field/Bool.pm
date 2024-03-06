package OpenXPKI::DTO::Field::Bool;

use Moose;
with 'OpenXPKI::DTO::Field';

has '+value' => (
    isa => 'Bool'
);

1;
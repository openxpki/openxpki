package OpenXPKI::DTO::Field::Epoch;

use Moose;
use Moose::Util::TypeConstraints;
with 'OpenXPKI::DTO::Field';

use OpenXPKI::DateTime;

subtype 'Epoch',
    as 'Int';

coerce 'Epoch',
    from 'Str',
    via { OpenXPKI::DateTime::get_validity({ VALIDITYFORMAT => 'detect', VALIDITY => $_} )->epoch() };

has '+value' => (
    isa => 'Epoch',
    coerce => 1,
);

__PACKAGE__->meta->make_immutable;

1;

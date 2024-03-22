package OpenXPKI::DTO::Field::File;

use Moose;
use Moose::Util::TypeConstraints;

with 'OpenXPKI::DTO::Field';

has '+name' => (
    default => 'file',
);

subtype 'ReadableFile',
    as 'Str',
    where { -f $_  && -r $_ },
    message { sprintf "'%s' is not a valid or accessible file",  $_ };

has '+value' => (
    isa => 'ReadableFile',
);

__PACKAGE__->meta->make_immutable;

1;

package OpenXPKI::DTO::Field::Directory;

use Moose;
use Moose::Util::TypeConstraints;

with 'OpenXPKI::DTO::Field';

has '+name' => (
    default => 'path',
);

subtype 'ReadablePath',
    as 'Str',
    where { -d $_ && -r $_ },
    message { sprintf "'%s' is not a valid or accessible directory",  $_ };

has '+value' => (
    isa => 'ReadablePath',
);

__PACKAGE__->meta->make_immutable;

1;

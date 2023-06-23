package OpenXPKI::Client::UI::Response::SectionRole;
use Moose::Role;

use Moose::Util::TypeConstraints qw( enum ); # PLEASE NOTE: this enables all warnings via Moose::Exporter

has 'type' => (
    is => 'rw',
    isa => enum([qw( text keyvalue grid form chart tiles )]),
);

has 'label' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has 'description' => (
    is => 'rw',
    isa => 'Str',
    documentation => 'content/',
);

has 'buttons' => (
    is => 'rw',
    isa => 'ArrayRef[HashRef]',
    documentation => 'content/',
);

1;

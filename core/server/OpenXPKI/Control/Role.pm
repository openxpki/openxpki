package OpenXPKI::Control::Role;
use OpenXPKI -role;

requires 'getopt_params';

requires 'start';
requires 'stop';
requires 'reload';
requires 'restart';
requires 'status';

has config_path => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_config_path',
);

has args => (
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { [] },
);

has opts => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
);

1;

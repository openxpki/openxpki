package OpenXPKI::Control::Role;
use OpenXPKI -role;

requires 'getopt_params';

requires 'cmd_start';
requires 'cmd_stop';
requires 'cmd_reload';
requires 'cmd_restart';
requires 'cmd_status';

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

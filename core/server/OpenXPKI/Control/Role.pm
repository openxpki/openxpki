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

1;

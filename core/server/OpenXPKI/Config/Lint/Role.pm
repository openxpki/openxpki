package OpenXPKI::Config::Lint::Role;

use Moose::Role;

has 'error' => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 0,
    default => sub { return []; }
);

has 'logger' => (
    required => 0,
    lazy => 1,
    is => 'ro',
    isa => 'Object',
    'default' => sub{ return Log::Log4perl->get_logger( ); }
);

1;

__END__;

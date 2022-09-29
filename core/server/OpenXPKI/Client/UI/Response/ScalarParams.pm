package OpenXPKI::Client::UI::Response::ScalarParams;

use Moose;

with 'OpenXPKI::Client::UI::Response::DTORole';

has 'rtoken' => (
    is => 'rw',
    isa => 'Str',
);

has 'language' => (
    is => 'rw',
    isa => 'Str',
);

has 'tenant' => (
    is => 'rw',
    isa => 'Str',
);

has 'ping' => (
    is => 'rw',
    isa => 'Str',
);

sub is_set { shift->has_any_value }

__PACKAGE__->meta->make_immutable;

package OpenXPKI::DTO::Field::Realm;

use Moose;
with 'OpenXPKI::DTO::Field';

has '+name' => (
    default => 'realm',
);

has '+label' => (
    default => 'PKI Realm',
);

has '+description' => (
    default => 'The name of the realm to operate this command on',
);

has '+value' => (
    isa => 'Str',
);

has '+hint' => (
    default => 'list_realm',
);

has '+required' => (
    default => 1
);

__PACKAGE__->meta->make_immutable;

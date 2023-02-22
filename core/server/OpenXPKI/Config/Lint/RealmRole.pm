package OpenXPKI::Config::Lint::RealmRole;
use Moose::Role;

with 'OpenXPKI::Config::Lint::Role';

requires 'lint_realm';

# only test this realm if specified
has realm => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

# required by OpenXPKI::Config::Lint::Role
sub lint {
    my $self = shift;

    foreach my $realm (sort $self->config->get_keys(['system','realms'])) {
        next if ($self->realm and $realm ne $self->realm);

        $self->set_heading('realm' => $realm);
        $self->lint_realm($realm);
    }
    $self->finish_heading('realm');

    return $self->global_error_count;
}

1;

__END__;

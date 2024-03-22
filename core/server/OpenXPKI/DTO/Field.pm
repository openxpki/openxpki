package OpenXPKI::DTO::Field;

use Moose::Util::TypeConstraints qw( find_type_constraint );
use List::Util qw( any );

use Moose::Role;

# The name of the parameter (as seen from external)
has name => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

# Verbose label (short!) to show during "inline help"
has label => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => sub { shift->name }
);

# Verbose text to show in "verbose help" mode
has description => (
    is => 'ro',
    isa => 'Str',
    default => '',
);

# Used to check the type constraint during validation
# preset value is used as default when used
has value => (
    is => 'rw',
    isa => 'Item',
    predicate => 'has_value'
);

# Field is required
has required => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

# Values are "enumerable" and can be retrieved by the caller
has hint => (
    is => 'ro',
    isa => 'Str|Undef',
    default => undef
);

sub getopt_type {

    my $class = shift;
    return $class->map_value_type({
        'Int' => 'i',
        'Num' => 'f',
        'Str' => 's',
        'Bool' => '',
    });

}

sub openapi_type {

    my $class = shift;
    return $class->map_value_type({
        'Int' => 'integer',
        'Num' => 'numeric',
        'Str' => 'string',
        'Bool' => 'boolean',
    });
}

sub map_value_type {

    my $class = shift;
    my $map = shift;
    my %moose_to_x = %{$map};

    my $value_attr = $class->meta->get_attribute('value') or die 'No "value"';
    my @to_check = $value_attr->type_constraint or die '"value" has no type type constraint';


    while (my $type = shift @to_check) {
        return $moose_to_x{$type->name} if any { $type->name eq $_ } keys %moose_to_x;

        # Type coercion - check all "from" types
        if ($type->has_coercion) {
            push @to_check, map { find_type_constraint($_) } $type->coercion->type_coercion_map->@*;
        }

        # Union type ("Str | Undef") - check all parts
        if ($type->isa('Moose::Meta::TypeConstraint::Union')) {
            push @to_check, $type->type_constraints->@*;

        # Derived type - check parent
        } elsif ($type->has_parent) {
            push @to_check, $type->parent;
        }
    }

    return;
}

1;
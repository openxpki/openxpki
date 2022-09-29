package OpenXPKI::Client::UI::Response::DTORole;

use Moose::Role;

# Core modules
use List::Util qw( any );

requires 'is_set';

sub resolve {
    my $self = shift;

    my $result = {};
    for my $attr ($self->meta->get_all_attributes) {
        # check which attributes are set
        next unless $attr->has_value($self);
        # use either 'documentation' or the attribute name as the key
        my $key = $attr->{documentation} || $attr->name;
        $result->{$key} = $attr->get_value($self);
    }

    return $result;
}

sub has_any_value {
    my $self = shift;

    return any { $_->has_value($self) } $self->meta->get_all_attributes;
}

1;

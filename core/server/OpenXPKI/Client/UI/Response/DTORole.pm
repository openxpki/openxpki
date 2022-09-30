package OpenXPKI::Client::UI::Response::DTORole;

use Moose::Role;

# Core modules
use List::Util qw( any );

# CPAN modules
use Moose::Util qw( does_role );

requires 'is_set';

=head2 resolve

Returns a I<HashRef> with all attribute values (if they are set).

Per default, the attribute name is used as hash key. To override this the
Moose attribute parameter I<documentation> may be used.

Nested hash structures as output may be defined using slashes C<I> as
delimiter. A trailing slash is a shortcut and means: append the attribute name.

    package Example;
    use Moose;
    with 'OpenXPKI::Client::UI::Response::DTORole';

    has 'descr' => (is => 'rw', isa => 'Str', documentation => 'description');
    has 'label' => (is => 'rw', isa => 'Str', documentation => 'meta/title');
    has 'size' => (is => 'rw', isa => 'Str', documentation => 'meta/sub/');

    # Elsewhere:
    my $response = Example->new(
        descr => 'abc',
        label => 'info',
        size => 23,
    )->resolve;

    # {
    #    description => 'abc',
    #    meta => {
    #        title => 'info',
    #        sub => {
    #            size => 23,
    #        },
    #    },
    # }

=cut
sub resolve {
    my $self = shift;

    my $result = {};
    for my $attr ($self->meta->get_all_attributes) {
        # check which attributes are set
        next unless $attr->has_value($self);
        # use either 'documentation' or the attribute name as the key
        my $key = $attr->{documentation} // $attr->name;
        my @keyparts = split '/', $key, -1; # -1 = don't strip trailing empty fields
        # append attr name if key had trailing /
        $keyparts[-1] = $attr->name unless $keyparts[-1];
        # create tree structure in case of e.g. documentation => 'content/data/'
        my $parent = $result;
        for (my $i=0; $i < scalar(@keyparts) - 1; $i++) {
            my $k = $keyparts[$i];
            $parent->{$k} //= {};
            $parent = $parent->{$k};
        };
        # set value
        my $val = $attr->get_value($self);
        $parent->{$keyparts[-1]} = does_role($val, 'OpenXPKI::Client::UI::Response::DTORole') ? $val->resolve : $val;
    }

    return $result;
}

sub has_any_value {
    my $self = shift;

    return any { $_->has_value($self) } $self->meta->get_all_attributes;
}

1;

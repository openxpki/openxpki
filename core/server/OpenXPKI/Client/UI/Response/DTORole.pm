package OpenXPKI::Client::UI::Response::DTORole;

use Moose::Role;

# Core modules
use List::Util qw( any );

# CPAN modules
use Moose::Util qw( does_role );

=head1 DESCRIPTION

B<Not intended for direct use.> Please use L<OpenXPKI::Client::UI::Response::DTO>
instead.

=head1 METHODS

=head2 resolve

Returns a I<HashRef> with all attribute values (if they are set).

If an attribute value is itself an object that consumes
C<OpenXPKI::Client::UI::Response::DTORole> (or an L<ArrayRef> containing such
objects) the attribute value is transformed first. So a call to C<transform>
may lead to recursive calls of the same method in children (i.e. attributes of
the current object) and so on.

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
    my @all_attrs = $self->meta->get_all_attributes;
    for my $attr (@all_attrs) {
        # check which attributes are set
        next unless $attr->has_value($self);
        # use either 'documentation' or the attribute name as the key
        my $key = $attr->{documentation} // $attr->name;

        next if 'IGNORE' eq $key;

        # make sure there's only one attribute if it is marked as 'ROOT'
        die sprintf "Error in %s: attribute '%s' is marked as 'ROOT' - no other attributes are allowed\n", $self->meta->name, $attr->name
            if ('ROOT' eq $key and scalar @all_attrs > 1);

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

        # transform value if it's a DTO or an ArrayRef of DTOs
        my $val = $attr->get_value($self);
        my $maybe_resolve = sub { my $v = shift; return (does_role($v, 'OpenXPKI::Client::UI::Response::DTORole') ? $v->resolve : $v) };
        if ($attr->type_constraint->is_a_type_of('ArrayRef')) {
            $val = [ map { $maybe_resolve->($_) } @{ $val } ];
        }
        else {
            $val = $maybe_resolve->($val);
        }

        if ('ROOT' eq $key) {
            # directly return value if marked as 'ROOT'
            return $val;
        }
        else {
            # store value in response hash
            $parent->{$keyparts[-1]} = $val;
        }
    }

    return $result;
}

=head2 is_set

Returns C<1> if any attributes of the consuming object have a value set (also
if a C<default> was specified).

Should be overridden if required.

=cut
sub is_set {
    my $self = shift;

    return any { $_->has_value($self) } $self->meta->get_all_attributes;
}

1;

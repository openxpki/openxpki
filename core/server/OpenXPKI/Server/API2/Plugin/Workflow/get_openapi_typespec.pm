package OpenXPKI::Server::API2::Plugin::Workflow::get_openapi_typespec;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_openapi_typespec

=cut

# Core modules
use Scalar::Util;

# CPAN modules
# Project modules

=head1 COMMANDS

=head2 get_openapi_typespec

Parses the given custom OpenXPKI shortcut syntax into an OpenAPI type specification.

Restrictions:

=over

=item * required attributes for objects cannot be specified

=back

B<Parameters>

=over

=item * C<spec> I<Str> - OpenXPKI's type specification string

=back

=cut
command "get_openapi_typespec" => {
    spec => { isa => 'Str', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $tree = $self->_parse($params->spec);
    return $self->_translate_to_openapi($tree);
};

# create an intermediate type spec tree (parse tree)
sub _parse {
    my ($self, $def) = @_;

    # basic checks
    my $opening = () = $def =~ /\[/g;
    my $closing = () = $def =~ /\]/g;
    die "Unbalanced square brackets in type definition: $def" unless $opening == $closing;

    $def =~ s/\s//gm;
    my $root = [ $def ];
    my @to_parse = ($root); # list of child enumerations to parse

    while (my $children = shift @to_parse) {
        for my $child (@$children) {
            my @parts = ($child =~ m/^ (?: ( [^\[\]():]+ ) : )? ( [^\[\]]+ ) (?: \[ (.*) \] )? $/msxi);
            die "Wrong syntax at OpenAPI type specification: $child" unless scalar @parts;

            my $inner = $parts[2];

            my @inner_parts = ();
            if ($inner) {
                # regex matching
                @inner_parts = ($parts[2] =~ m/
                    (?: [,\|]?
                        (
                            [^\[\],\|]+  # an item without sub items i.e. no brackets
                            (?: \[     # balanced bracket matching
                                (?:
                                    [^\[\]] | (?R)
                                )*
                            \] )?
                        )
                    )
                /gxi);
                push @to_parse, \@inner_parts;
            }

            # replace element in child list with parsed version (by assigning new content to lvalue for-loop variable)
            $child = {
                key => $parts[0],  # might be undef
                type => $parts[1], # mandatory
                inner => @inner_parts ? \@inner_parts: undef,
                raw => $child,
            };

        }
    }

    return $root;
}

# process the intermediate type spec tree and create an OpenAPI type definition tree
sub _translate_to_openapi {
    my ($self, $tree) = @_;

    my $root;
    my @todo = ( [ $tree->[0], undef, $tree->[0] ] );

    for my $todo (@todo) {
        my ($parent, $store_into, $srcdef, $key) = @$todo; # $key is only set if $store_into is a HashRef

        #
        # translate our intermediate type specs syntax into an OpenAPI type definition
        #
        my $targetdef;
        if ($srcdef->{type} =~ /^ Array(Ref)? $/xi) {
            $targetdef = { type => 'array' };

            my $array_item_type = $srcdef->{inner};
            # if array type(s) were specified
            if ($array_item_type) {
                if (scalar @$array_item_type == 1) {
                    push @todo, [ $srcdef, $targetdef, $array_item_type->[0], "items" ];
                }
                else {
                    my $items = [];
                    $targetdef->{items} = { oneOf => $items };
                    push @todo, [ $srcdef, $items, $_ ] for @$array_item_type; # add all items of the list
                }
            }
            # no array type specified
            else {
                $targetdef->{items} = {};
            }
        }

        elsif ($srcdef->{type} =~ /^ ( Obj(ect)? | Hash(Ref)? ) $/xi) {
            $targetdef = { type => 'object' };

            my $object_item_types = $srcdef->{inner};
            # if object properties were specified
            if ($object_item_types) {
                my $properties = {};
                $targetdef->{properties} = $properties;
                push @todo, [ $srcdef, $properties, $_, $_->{key} ] for @$object_item_types;
            }
        }

        elsif (my @parts = $srcdef->{type} =~ /^ ( Int(?:eger)? | Num(?:eric)? | Str(?:ing)? | Bool(?:ean)? ) (?: \( ( [^()]+ ) \) )? $/xi) {
            my ($type, $params) = @parts;
            $type = lc($type);
            $type = "string" if $type eq "str";
            $type = "integer" if $type eq "int";
            $type = "numeric" if $type eq "num";
            $type = "boolean" if $type eq "bool";

            $targetdef = { type => $type };

            # type parameters specified?
            if ($params) {
                for my $param (split ",", $params) {
                    my ($k,$v) = split /[:=]/, $param;
                    die "Invalid parameter syntax in round brackets in '".$srcdef->{raw}."'" unless defined $k && defined $v;
                    $v = $v+0 if Scalar::Util::looks_like_number($v); # OpenAPI complains about numeric parameters in quotes
                    $targetdef->{$k} = $v;
                }
            }
        }
        die "Unknown type: '".$srcdef->{type}."'" unless $targetdef;

        #
        # attach newly created OpenAPI type definition to the tree structure
        #
        if ($store_into) {
            if (ref $store_into eq "ARRAY") {
                push @$store_into, $targetdef;
            }
            else {
                die "An object property was specified without a name/key: ".$parent->{raw} unless $key;
                $store_into->{$key} = $targetdef;
            }
        }
        else {
            $root = $targetdef;
        }
    }

    return $root;
}

__PACKAGE__->meta->make_immutable;

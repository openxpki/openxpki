package OpenXPKI::Server::API2::Plugin::Workflow::get_openapi_typespec;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Workflow::get_openapi_typespec

=cut

# Core modules
use Scalar::Util;

# CPAN modules
# Project modules
use OpenXPKI::Debug;

# Allowed parameters for certain OpenAPI 3.0 data types.
# Source: https://swagger.io/docs/specification/data-models/data-types/
our %OPENAPI_ALLOWED_TYPE_PARAMETERS = (
    number =>  [ qw( format nullable enum minimum maximum exclusiveMinimum exclusiveMaximum multipleOf ) ],
    integer => [ qw( format nullable enum minimum maximum exclusiveMinimum exclusiveMaximum multipleOf ) ],
    string =>  [ qw( format nullable enum minLength maxLength pattern ) ],
);

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

    my $tree = $self->_parse_composition($params->spec);
    return $self->_translate_types($tree);
};

# create an intermediate type spec tree (parse tree)
sub _parse_composition {
    my ($self, $def) = @_;

    # basic checks
    my $opening = () = $def =~ / (?<! \\ ) \[ /gx;
    my $closing = () = $def =~ / (?<! \\ ) \] /gx;
    die "Unbalanced square brackets in type definition: $def" unless $opening == $closing;

    ##! 8: "Raw definition:     $def"

    # remove whitespaces outside enums <...>
    my $stripped_def = '';
    my $inside_brackets = 0;
    my $escape_char = 0;
    for my $char (split('', $def)) {
        if ($inside_brackets) {
            if ($escape_char)     { $escape_char = 0 }
            elsif ('\\' eq $char) { $escape_char = 1 }
            elsif ('>' eq $char)  { $inside_brackets = 0 }
            $stripped_def .= $char; next;
        }
        else {
            if ('<' eq $char) { $inside_brackets = 1 }
            elsif ($char =~ /\s/) { next }
            $stripped_def .= $char;
        }
    }

    $def = $stripped_def;

    ##! 8: "Whitespace cleanup: $def"

    my $root = [ $def ];
    my @to_parse = ($root); # list of child enumerations to parse

    while (my $children = shift @to_parse) {
        for my $child (@$children) {
            ##! 8: "COMPONENT: $child"
            my @parts = ($child =~ m/^
                (?:
                    (
                        [^\[\]():]+     # key (=name): anything but []():
                    )
                    :                   # colon
                )?
                (
                    (?: \\ [\[\]] | [^\[\]] )+    # type: anything but plain []
                )
                (?:
                    \[
                        (.*)            # inner type (=subtype): anything between []
                    \]
                )?
                $
            /msxi);
            die "Wrong syntax at OpenAPI type specification: $child" unless scalar @parts;

            my ($key, $type, $inner) = @parts;

            # Type ending with "!" denotes a required Hash item
            my $is_required_obj_item = (($type//"") =~ m/!$/); $type =~ s/!$//;

            ##! 8: "    KEY: " . ($key//"") . ($is_required_obj_item ? " (required item)" : "")
            ##! 8: "   TYPE: " . ($type//"")
            ##! 8: "  INNER: " . ($inner//"")

            my @inner_parts = ();
            if ($inner) {
                # regex matching
                @inner_parts = ($inner =~ m/
                        [,\|]?                          # comma or pipe
                        (?<squarebracketgroup>          # balanced square brackets [] or none
                            (?:                             # no square brackets:
                                (?<bracketgroup>                # balanced brackets () or none - needed e.g. to distinct commata inside brackets from those in square brackets
                                    (?:                             # no brackets:
                                        \\ [\[\]\(\),\|]                    # escaped bracket, comma or pipe
                                        |                               # or
                                          [^\[\]\(\),\|]                    # anything but plain bracket, comma or pipe
                                    )+
                                    (?:                             # maybe: balanced brackets ()
                                        (?<!\\) \(                      # opening balanced plain bracket
                                            (?:                         # inside:
                                                \\ [\[\]\(\)]                   # escaped bracket
                                                |                           # or
                                                  [^\[\]\(\)]                   # anything but plain bracket
                                                |                           # or
                                                (?&bracketgroup)        # recursively another "bracket group"
                                            )*
                                        (?<!\\) \)                      # closing balanced plain bracket
                                    )?
                                )
                            )+
                            (?:                             # maybe: balanced square brackets []
                                (?<!\\) \[                      # opening balanced (plain) bracket
                                    (?:                         # inside:
                                        \\ [\[\]]                   # escaped bracket
                                        |                           # or
                                          [^\[\]]                   # anything but plain bracket
                                        |                           # or
                                        (?&squarebracketgroup)      # recursively another "square bracket group"
                                    )*
                                (?<!\\) \]                      # closing balanced (plain) bracket
                            )?
                        )
                /gxi);
                die "Wrong syntax at OpenAPI type specification: $inner" unless scalar @inner_parts;

                # only take element 1, 3, 5 etc. (= outer capture group, the others are the inner "bracketgroup")
                my @temp = ();
                for (my $i = 0; $i <= $#inner_parts; $i++) {
                    push @temp, $inner_parts[$i] if $i % 2 == 0;
                }
                @inner_parts = @temp;

                ##! 8: "  INNER PARTS: " . Dumper(\@inner_parts)
                push @to_parse, \@inner_parts;
            }

            # replace element in child list with parsed version (by assigning new content to lvalue for-loop variable)
            $child = {
                key => $key,  # might be undef
                type => $type, # mandatory
                inner => @inner_parts ? \@inner_parts: undef, # will be substituted in later loop run
                raw => $child,
                is_required_obj_item => $is_required_obj_item,
            };

        }
    }

    return $root;
}

# process the intermediate type spec tree and create an OpenAPI type definition tree
sub _translate_types {
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
                $targetdef->{items} = {}; # OpenAPI treats {} as the "any-type"
            }
        }

        elsif ($srcdef->{type} =~ /^ ( Obj(ect)? | Hash(Ref)? ) $/xi) {
            $targetdef = { type => 'object' };

            my $object_items = $srcdef->{inner};
            # if object properties were specified
            if ($object_items) {
                # creat empty container for object properties
                my $properties = {};
                $targetdef->{properties} = $properties; # the HashRef will be populated in a later loop run
                # list required properties
                my @required = map { $_->{key} } grep { $_->{is_required_obj_item} } @$object_items;
                $targetdef->{required} = \@required if scalar @required;
                # append object item to processing queue
                push @todo, [ $srcdef, $properties, $_, $_->{key} ] for @$object_items;
            }
        }

        elsif (
            my @parts = $srcdef->{type} =~ /
                ^
                ( Int(?:eger)? | Num(?:eric)? | Str(?:ing)? | Bool(?:ean)? )
                (?:
                    \(                      # opening bracket
                        (
                            (?:             # no brackets:
                                \\ [\(\)]       # escaped brackets
                                |               # or
                                  [^\(\)]       # anything but plain brackets
                            )+
                        )
                    \)                      # closing bracket
                )?
                $
            /xi
        ) {
            my ($type, $param_str) = @parts;
            ##! 8: "TYPE: $type"
            ##! 8: "  PARAMS: " . ($param_str//"")
            $type = lc($type);
            $type = "string" if $type eq "str";
            $type = "integer" if $type eq "int";
            $type = "numeric" if $type eq "num";
            $type = "boolean" if $type eq "bool";

            $targetdef = { type => $type };

            # type parameters specified?
            if ($param_str) {
                my @params = $param_str =~ m/
                    ,?                              # comma?
                    (                               # balanced brackets <> or none (for enum)
                        (?:                             # no brackets:
                            \\ [<>,]                        # escaped bracket <> or comma
                            |                               # or
                              [^<>,]                        # anything but plain bracket or comma
                        )+
                        (?:                             # maybe: balanced brackets <>
                            (?<!\\) <                       # opening balanced plain bracket
                                (?:                         # inside:
                                    \\ [<>]                     # escaped bracket
                                    |                           # or
                                      [^<>]                     # anything but plain bracket
                                )*
                            (?<!\\) >                       # closing balanced plain bracket
                        )?
                    )
                /gxi;

                for my $param (@params) {
                    ##! 8: "    PARAM: $param"
                    my ($k,@v) = split /:/, $param;
                    my $v = join ":", @v;
                    die "Invalid parameter syntax in round brackets in '".$srcdef->{raw}."'" unless defined $k && scalar @v;

                    # check if type allows this parameter
                    if (my $allowed = $OPENAPI_ALLOWED_TYPE_PARAMETERS{$type}) {
                        die "Parameter '$k' not allowed in OpenAPI type '$type'" unless scalar grep { m/^\Q$k\E$/ } @$allowed;
                    }

                    # OpenAPI complains about numeric parameters in quotes. If
                    # we convert them to Perl's internal number representation
                    # then JSON will output them without quotes.
                    $v = $v+0 if Scalar::Util::looks_like_number($v);

                    # enum
                    if (lc($k) eq "enum") {
                        ##! 8: "      ENUM: $v"
                        $v =~ s/ ^ < (.*) > $ /$1/msxi;
                        my @enum_values = $v =~ m/
                            ,?                  # comma
                            (
                                (?:             # no brackets or comma:
                                    \\ [<>,]        # escaped bracket <> or comma
                                    |               # or
                                      [^<>,]        # anything but plain bracket or comma
                                )+
                            )
                        /gxi;

                        # convert to numbers if parent type is integer or number
                        if ("integer" eq $type or "number" eq $type) {
                            @enum_values = map { $_+0 } @enum_values ;
                        }
                        # unescape backslash escaped characters
                        elsif ("string" eq $type) {
                            @enum_values = map { s/ \\ (.) /$1/gmx; $_ } @enum_values ;
                        }

                        ##! 8: "      ENUM VALUES: " . Dumper(\@enum_values)
                        $targetdef->{$k} = \@enum_values;
                    }
                    # plain parameter
                    else {
                        $targetdef->{$k} = $v;
                    }
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

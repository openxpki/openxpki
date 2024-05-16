package OpenXPKI::Server::API2::PluginMetaClassTrait;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::Server::API2::PluginMetaClassTrait - Moose metaclass role (aka.
"trait") for API plugins

=head1 DESCRIPTION

B<Not intended for direct use:> please C<use OpenXPKI -plugin> instead.

Manage API parameters and their specifications for the API plugin classes.
This role/trait is applied by L<OpenXPKI::Server::API2::Plugin>.

=head1 ATTRIBUTES

#             namespace => 'OpenXPKI::Server::API2::Plugin::test',
=cut
has namespace => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_namespace',
);

=head1 METHODS

=head2 command_list

Returns a I<list> with all API command names defined by the API plugin.

=cut

# Command meta information I<HashRef>:
#     {
#         'command_1' => {
#             param_metaclass => Moose::Meta::Class->create(...),
#             is_protected => 0,
#         },
#         'command_2' => {
#             ...
#         }
#     }
has _command_meta => (
    is => 'rw',
    isa => 'HashRef',
    traits => [ 'Hash' ],
    handles => {
        command_list => 'keys',
    },
    default => sub { {} },
);

=head2 add_param_specs

Add parameter specifications for the given API command.

A new L<Moose::Meta::Class> is created with the name I<${command}_ParamObject>.
Attributes are added to this class which will store the API command parameters.
Type constraints specified via the L<C<matching>|OpenXPKI::Server::API2::Plugin/command>
parameter are created and attached to the attributes.

B<Parameters>

=over

=item * C<$command> - API command name

=item * C<$param_specs> - parameter specification I<HashRef>

Keys are parameter names that will be turned into Moose attributes of a newly
generated container class (type L<Moose::Meta::Class>).

Values are I<HashRefs> with the attribute options (extended version of Moose's I<has>
keyword options).

For more details please see L<OpenXPKI::Server::API2::Plugin/command>.

=back

=cut
signature_for add_param_specs => (
    method => 1,
    positional => [ 'Str', 'HashRef' ],
);
sub add_param_specs ($self, $command, $params_specs) {
    my $param_metaclass = Moose::Meta::Class->create(
        join("::", $self->name, "${command}_Params"),
    );

    # Add API command parameters to the newly created class as Moose attributes
    for my $param_name (sort keys $params_specs->%*) {
        # the parameter specs like "isa => ..., required => ..."
        my $spec = { $params_specs->{$param_name}->%* }; # copy params to prevent modifying it via delete() below

        OpenXPKI::Exception->throw(
            message => "'isa' must specified when defining an API command parameter",
            params => { command => $command, parameter => $param_name, spec => Dumper($spec) }
        ) unless $spec->{isa};

        my $isa = delete $spec->{isa};
        if ($spec->{matching}) {
            # FIXME Implement
            my $matching = delete $spec->{matching};
            OpenXPKI::Exception->throw(
                message => "'matching' must be a reference either of type Regexp or CODE",
                params => { command => $command, parameter => $param_name }
            ) unless (ref $matching eq 'Regexp' or ref $matching eq 'CODE');

            require Moose::Util::TypeConstraints;
            my $parent_type = Moose::Util::TypeConstraints::find_or_create_isa_type_constraint($isa);
            # we create a new anonymous subtype and overwrite the old type in $isa
            $isa = Moose::Meta::TypeConstraint->new(
                parent => $parent_type,
                constraint => ( ref $matching eq 'CODE' ? $matching : sub { $_ =~ $matching } ),
                message => sub { my $val = shift; return "either attribute is not a '$parent_type' or constraints defined in 'matching' where violated" },
            );
        }
        # add a Moose attribute to the parameter container class
        $param_metaclass->add_attribute($param_name,
            isa => $isa,
            accessor => $param_name,
            clearer => "clear_${param_name}",
            predicate => "has_${param_name}",
            $spec->%*,
        );
    }
    # internally register the new parameter class
    $self->param_metaclass($command, $param_metaclass);
}

=head2 param_metaclass

Accessor to set or retrieve a L<Moose::Meta::Class> defining the parameters for
the given command.

    $self->param_metaclass($cmd);                                  # getter
    $self->param_metaclass($cmd, Moose::Meta::Class->create(...)); # setter

=cut
sub param_metaclass ($self, $command, $param_metaclass = undef) {
    return $self->_set_cmd_meta($command, 'param_metaclass', $param_metaclass);
}

=head2 is_protected

Accessor to set or retrieve the protection status of the given command.

    $self->is_protected($cmd);      # getter
    $self->is_protected($cmd, 1);   # setter

=cut
sub is_protected ($self, $command, $is_protected = undef) {
    return $self->_set_cmd_meta($command, 'is_protected', $is_protected);
}

# Getter / Setter for arbitrary command meta data
sub _set_cmd_meta ($self, $command, $spec, $value) {
    if (defined $value) {
        $self->_command_meta->{$command}->{$spec} = $value;
    } else {
        die "API command '$command' is not managed by " . __PACKAGE__
          unless $self->_command_meta->{$command};
    }

    return $self->_command_meta->{$command}->{$spec};
}

=head2 new_param_object

Wraps the given command parameters into an instance of an auto-generated
parameter class.

All parameters will be available as Moose attributes.

Example:

    my $po = $plugin->meta->new_param_object("doit", { fish => 'cod', size => 55 });
    printf "%s: %s\n", $po->fish, $po->size;

A L<Moose::Exception::ValidationFailedForTypeConstraint> will be thrown if
a parameter does not fulfill the type constraints specified in the call to L<add_param_specs>.

B<Parameters>

=over

=item * C<$command> - API command name

=item * C<$params> - parameter I<HashRef>

=back

=cut
sub new_param_object ($self, $command, $params) {
    ##! 4: "API: new_param_object($command => {".join(", ", map { "$_ => ".$params->{$_} } keys %{ $params })."})"
    return $self->param_metaclass($command)->new_object($params->%*);
}

# =head2 execute

# Executes the given API command.

# =cut
# signature_for execute => (
#     method => 1,
#     positional => [ 'OpenXPKI::Server::API2', 'Str', 'HashRef' ],
# );
# sub execute ($self, $api, $command, $params) {
#     my $instance = $self->new_object(rawapi => $api);
#     my $param_obj = $self->new_param_object($command, $params); # provided by OpenXPKI::Server::API2::PluginMetaClassTrait
#     return $self->find_method_by_name($command)->execute($instance, $param_obj);
# }

1;

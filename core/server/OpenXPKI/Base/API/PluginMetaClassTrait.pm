package OpenXPKI::Base::API::PluginMetaClassTrait;
use OpenXPKI qw( -role -typeconstraints );

# Core modules
use List::Util qw( any );

# CPAN modules
use Moose::Meta::TypeConstraint;
use Moose::Util ();

=head1 NAME

OpenXPKI::Base::API::PluginMetaClassTrait - Moose metaclass role (aka.
"trait") for API plugins

=head1 DESCRIPTION

B<Not intended for direct use> - this is part of the internal API magic.

Manage API parameters and their specifications for the API plugin classes.
This role/trait is applied by L<OpenXPKI::Base::API::Plugin>.

=head1 ATTRIBUTES

=head2 namespace

The namespace I<Str> of the commands defined in the current class.

Default to C<""> (empty string), which is the
L<root namespace|OpenXPKI::Base::API::APIRole/namespace> of the API.

=cut
has namespace => (
    is => 'rw',
    isa => 'Str',
    predicate => 'has_namespace',
);

=head1 METHODS

=head2 add_default_attribute_spec

Add the given attribute specification to all commands of the plugin.

    $self->meta->add_default_attribute_spec(
        realm => { is => 'Str', required => 1, label => 'PKI Realm' },
    );

Accepts the same options as the C<$param_specs> hash of L</add_param_specs>
and thus the same as the C<$params> hash in
L<OpenXPKI::Base::API::Plugin/command>.

=cut
has _default_attribute_specs => (
    is => 'rw',
    isa => 'HashRef[HashRef]',
    traits => [ 'Hash' ],
    handles => {
        add_default_attribute_spec => 'set',
    },
    default => sub { {} },
);

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
Type constraints specified via the L<C<matching>|OpenXPKI::Base::API::Plugin/command>
parameter are created and attached to the attributes.

B<Parameters>

=over

=item * C<$command> - API command name

=item * C<$param_specs> - parameter specification I<HashRef>

Keys are parameter names that will be turned into Moose attributes of a newly
generated container class (type L<Moose::Meta::Class>).

Values are I<HashRefs> with the attribute options (extended version of Moose's I<has>
keyword options).

When using any type with a coercion the C<coerce =E<gt> 1> option will
automatically be set.

For more details please see L<OpenXPKI::Base::API::Plugin/command>.

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
    $self->_add_attributes($command, $param_metaclass, $params_specs);
    # Add default API command parameters
    $self->_add_attributes($command, $param_metaclass, $self->_default_attribute_specs);
    # internally register the new parameter class
    $self->param_metaclass($command, $param_metaclass);
}

signature_for _add_attributes => (
    method => 1,
    positional => [ 'Str', 'Moose::Meta::Class', 'HashRef' ],
);
sub _add_attributes ($self, $command, $param_metaclass, $params_specs) {
    for my $param_name (sort keys $params_specs->%*) {
        # the parameter specs like "isa => ..., required => ..."
        my $spec = { $params_specs->{$param_name}->%* }; # copy params to prevent modifying it via delete() below

        OpenXPKI::Exception->throw(
            message => "Parameter '$param_name' collides with default parameter of same name",
            params => { command => $command, parameter => $param_name, spec => Dumper($spec) }
        ) if (any { $param_name eq $_ } keys $self->_default_attribute_specs->%*);

        OpenXPKI::Exception->throw(
            message => "'isa' must be specified when defining an API command parameter",
            params => { command => $command, parameter => $param_name, spec => Dumper($spec) }
        ) unless $spec->{isa};

        my $isa = delete $spec->{isa};
        my $type = Moose::Util::TypeConstraints::find_or_create_isa_type_constraint($isa);

        if ($spec->{matching}) {
            # FIXME Implement
            my $matching = delete $spec->{matching};
            OpenXPKI::Exception->throw(
                message => "'matching' must be a reference either of type Regexp or CODE",
                params => { command => $command, parameter => $param_name }
            ) unless (ref $matching eq 'Regexp' or ref $matching eq 'CODE');

            # we create a new anonymous subtype and overwrite the old type in $isa
            $isa = Moose::Meta::TypeConstraint->new(
                parent => $type,
                constraint => ( ref $matching eq 'CODE' ? $matching : sub { $_ =~ $matching } ),
                message => sub { my $val = shift; return "either attribute is not a '$type' or constraints defined in 'matching' where violated" },
            );
        }
        # add a Moose attribute to the parameter container class

        $param_metaclass->add_attribute($param_name,
            is => 'rw',
            isa => $isa,
            traits => [ 'OpenXPKI::Base::API::ParamAttributeTrait' ],
            accessor => $param_name,
            clearer => "clear_${param_name}",
            predicate => "has_${param_name}",
            $type->has_coercion ? (coerce => 1) : (),
            $spec->%*,
        );
    }
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

signature_for set_command_behaviour => (
    method => 1,
    named => [
        caller => 'Str',
        namespace => 'Str', { optional => 1 },
        namespace_role => 'Str', { optional => 1 },
        parent_namespace => 'Bool', { default => 0 },
        parent_namespace_role => 'Bool', { default => 0 },
        needs_realm => 'Bool', { default => 0 },
        protected => 'Bool', { default => 0 },
    ],
);
sub set_command_behaviour ($self, $arg) {
    if (my $namespace = $arg->namespace || $arg->namespace_role) {
        $self->namespace($namespace);
        Moose::Util::apply_all_roles($self, $namespace) if $arg->namespace_role;
    }
    elsif (my $set_parent_ns = $arg->parent_namespace || $arg->parent_namespace_role) {
        my @parts = split '::', $arg->caller; pop @parts;
        my $parent_ns = join '::', @parts;
        $self->namespace($parent_ns);
        Moose::Util::apply_all_roles($self, $parent_ns) if $arg->parent_namespace_role;
    }

    if ($arg->needs_realm) {
        $self->add_default_attribute_spec(
            realm => {
                isa => 'Str', required => 1,
                label => 'PKI Realm', description => 'Name of the realm to operate this command on',
                hint => 'list_realm',
            }
        );
    }

    # TODO Implement command_setup(protected => 1) or replace it with protected_command
}

# =head2 execute

# Executes the given API command.

# =cut
# signature_for execute => (
#     method => 1,
#     positional => [ 'OpenXPKI::Base::API::APIRole', 'Str', 'HashRef' ],
# );
# sub execute ($self, $api, $command, $params) {
#     my $instance = $self->new_object(rawapi => $api);
#     my $param_obj = $self->new_param_object($command, $params); # provided by OpenXPKI::Base::API::PluginMetaClassTrait
#     return $self->find_method_by_name($command)->execute($instance, $param_obj);
# }

1;

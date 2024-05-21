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
#             param_spec => { ... },                                # raw parameters
#             param_metaclass => Moose::Meta::Class->create(...),   # class lazily created from raw parameters
#             is_protected => 0,                                    # flag for protected commands
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

=head2 param_specs

Accessor to set or retrieve parameter specifications for the given API command.

Eventually a new L<Moose::Meta::Class> will be created with the name
I<${command}_ParamObject>.

Attributes are added to this class which will store the API command parameters.
Type constraints specified via the L<C<matching>|OpenXPKI::Base::API::Plugin/command>
parameter are created and attached to the attributes.

The class creation is deferred to speed up API initialization and to allow
for L</add_default_attribute_spec> to come into effect first.

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

signature_for param_specs => (
    method => 1,
    positional => [ 'Str', 'Optional[HashRef]' ],
);
sub param_specs ($self, $command, $specs = undef) {
    return $self->_cmd_meta($command, 'param_specs', $specs);
}

=head2 get_param_metaclass

Retrieve/create a L<Moose::Meta::Class> defining the parameters for the given
command.

    $self->get_param_metaclass($cmd);

=cut
sub get_param_metaclass ($self, $command) {
    my $metaclass = $self->_cmd_meta($command, 'param_metaclass');

    # Getter: create meta class on first access
    if (not defined $metaclass) {
        my $param_specs = $self->param_specs($command)
          or die "No parameter specifications found for command '$command'\n";

        $metaclass = Moose::Meta::Class->create(
            join("::", $self->name, "${command}_Params"),
        );

        try {
            # Add API command parameters to the newly created class as Moose attributes
            $self->_add_attributes($metaclass, $param_specs);
            # Add default API command parameters
            $self->_add_attributes($metaclass, $self->_default_attribute_specs, 1);
            # internally register the new parameter class
            $self->_cmd_meta($command, 'param_metaclass', $metaclass);
        }
        catch ($err) {
            OpenXPKI::Exception->throw(
                message => "API command '$command': $err",
                params => { command => $command, spec => Dumper($param_specs) }
            );
        }
    }

    return $metaclass;
}

=head2 is_protected

Accessor to set or retrieve the protection status of the given command.

    $self->is_protected($cmd);      # getter
    $self->is_protected($cmd, 1);   # setter

=cut
sub is_protected ($self, $command, $is_protected = undef) {
    return $self->_cmd_meta($command, 'is_protected', $is_protected);
}

# Getter / Setter for arbitrary command meta data
signature_for _cmd_meta => (
    method => 1,
    positional => [ 'Str', 'Str', 'Optional[Any]' ],
);
sub _cmd_meta ($self, $command, $spec, $value = undef) {
    if (defined $value) {
        $self->_command_meta->{$command}->{$spec} = $value;
    } else {
        die "API command '$command' is not managed by " . __PACKAGE__
          unless $self->_command_meta->{$command};
    }

    return $self->_command_meta->{$command}->{$spec};
}

# add attributes to command parameter meta class
signature_for _add_attributes => (
    method => 1,
    positional => [ 'Moose::Meta::Class', 'HashRef', 'Optional[Bool]' ],
);
sub _add_attributes ($self, $param_metaclass, $param_specs, $is_default = 0) {
    for my $param_name (sort keys $param_specs->%*) {
        # the parameter specs like "isa => ..., required => ..."
        my $spec = { $param_specs->{$param_name}->%* }; # copy params to prevent modifying it via delete() below

        die "Parameter '$param_name' collides with default parameter of same name\n"
          if (not $is_default and any { $param_name eq $_ } keys $self->_default_attribute_specs->%*);

        die "'isa' missing in parameter '$param_name'\n"
          unless $spec->{isa};

        my $isa = delete $spec->{isa};
        my $type = Moose::Util::TypeConstraints::find_or_create_isa_type_constraint($isa);

        if ($spec->{matching}) {
            my $matching = delete $spec->{matching};
            die "'matching' must be a reference of type Regexp or CODE in parameter '$param_name'\n"
              unless (ref $matching eq 'Regexp' or ref $matching eq 'CODE');

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
    return $self->get_param_metaclass($command)->new_object($params->%*);
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

package OpenXPKI::Server::API2::EasyPluginMetaClassTrait;
use Moose::Role;

=head1 NAME

OpenXPKI::Server::API2::EasyPluginMetaClassTrait - Moose metaclass role (aka.
"trait") for API plugins

=head2 DESCRIPTION

B<Not intended for direct use.> Please C<use OpenXPKI::Server::API2::EasyPlugin;>
instead.

This role manages API parameters and their specifications for the API plugin classes.
It will be applied when you say C<use OpenXPKI::Server::API2::EasyPlugin>.

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;


=head1 ATTRIBUTES

=head2 param_classes

Returns a I<HashRef>: keys are the API command names and values the auto-generated
parameter classes of type L<Moose::Meta::Class>.

=head1 METHODS

=head2 command_list

Returns a I<list> with all API command names defined by the API plugin.

=cut
has param_classes => (
    is => 'rw',
    isa => 'HashRef[Str]',
    traits => [ 'Hash' ],
    handles => {
        command_list => 'keys',
    },
    default => sub { {} },
);

=head2 add_param_specs

Adds parameter specifications for the given API command.

A new L<Moose::Meta::Class> is created with the name I<${command}_ParamObject>.
Attributes are added to the class that will hold the API command parameters.
Type constraints specified via 'matching' are created and attached to the
attributes.

B<Parameters>

=over

=item * C<$command> - API command name

=item * C<$param_specs> - parameter specification I<HashRef>

Keys are parameter names that will be turned into Moose attributes of a newly
generated container class (type L<Moose::Meta::Class>).

Values are I<HashRefs> with the attribute options (extended version of Moose's I<has>
keyword options).

For more details please see L<OpenXPKI::Server::API2::EasyPlugin/command>.

=back

=cut
sub add_param_specs {
    my ($self, $command, $params_specs) = @_;

    my $param_metaclass = Moose::Meta::Class->create(
        join("::", $self->name, "${command}_ParamObject"),
    );

    # Add API command parameters to the newly created class as Moose attributes
    for my $param_name (sort keys %{ $params_specs }) {
        # the parameter specs like "isa => ..., required => ..."
        my $spec = $params_specs->{$param_name};

        OpenXPKI::Exception->throw(
            message => "'isa' must specified when defining an API command parameter",
            params => { command => $command, parameter => $param_name }
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
            %{ $spec },
        );
    }
    # internally register the new parameter class
    $self->param_classes->{$command} = $param_metaclass;
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
sub new_param_object {
    my ($self, $command, $params) = @_;
    ##! 4: "API: new_param_object($api_method, ".join(", ", map { "$_ => ".$params->{$_} } keys %{ $params }).")"

    my $param_metaclass = $self->param_classes->{$command}
        or OpenXPKI::Exception->throw (
            message => "API command $command is not managed by __PACKAGE__",
            params => { command => $command }
        );

    return $param_metaclass->new_object(%{ $params });
}

1;

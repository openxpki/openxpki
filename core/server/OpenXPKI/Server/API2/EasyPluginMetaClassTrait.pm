package OpenXPKI::Server::API2::EasyPluginMetaClassTrait;
use Moose::Role;

=head1 NAME

OpenXPKI::Server::API2::EasyPluginMetaClassTrait - Moose metaclass role (aka.
"trait") for API plugins

=head2 DESCRIPTION

B<Not intended to be used directly.>

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
        if ($spec->{matching}) {
            # FIXME Implement
            delete $spec->{matching};
        }
        # add a Moose attribute to the parameter container class
        $param_metaclass->add_attribute($param_name,
            is => 'ro',
            %{ $spec },
        );
    }

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

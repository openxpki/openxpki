package OpenXPKI::Server::API2::EasyPluginMetaClassTrait;
use Moose::Role;

=head1 Name

OpenXPKI::Server::API2::EasyPluginMetaClassTrait - Moose metaclass role (aka.
"trait") for API plugins

=head2 Description

This role is not intended to be used directly. It will be applied when you say
C<use OpenXPKI::Server::API2::EasyPlugin>.

This role adds meta functionality to the classes that implement API commands.

=cut

has param_classes => (
    is => 'rw',
    isa => 'HashRef[Str]',
    default => sub { {} },
);

# Create a class that will hold the parameter values
sub add_param_class {
    my ($self, $api_method, $params_specs) = @_;

    my $param_metaclass = Moose::Meta::Class->create(
        join("::", $self->name, "${api_method}_ParamObject"),
#        superclasses => ,
#        roles => ,
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

    $self->param_classes->{$api_method} = $param_metaclass;
}

sub new_param_object {
    my ($self, $api_method, %params) = @_;
    my $param_metaclass = $self->param_classes->{$api_method};
    die "API method $api_method is not managed by __PACKAGE__\n" unless $param_metaclass;
    use Test::More;
    diag "==> new_param_object($api_method, ".join(", ", map { "$_ => $params{$_}" } keys %params).")";
    my $param_object = $param_metaclass->new_object(%params);
    diag "==> object created";
    return $param_object;
}

1;

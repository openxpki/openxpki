package OpenXPKI::Server::API2::Command;
=head1 Name

OpenXPKI::Server::API2::Command

=cut

# CPAN modules
use Moose ();
use Moose::Exporter;
use Moose::Util;
use Moose::Util::MetaRole;
use B::Hooks::EndOfScope;

# Project modules
use OpenXPKI::Server::API2::CommandMetaClassTrait;

#
# Exports (imported when calling "use OpenXPKI::Server::API2::Command;")
#
Moose::Exporter->setup_import_methods(
    with_meta => [ "api" ],
    also => "Moose",
);

# Moose::Exporter will call init_meta() when the IMPORT function is called.
# $args{for_class} contains the metaclass of the class that imports us.
sub init_meta {
    shift; # our class name
    my %args = @_;

    Moose->init_meta(%args);
    my $importing_class_meta = $args{for_class}->meta;

    # We modify the class that imports us:
    # 1. change the classes' metaclass to be able to use the api_param_classes() HashRef
    Moose::Util::MetaRole::apply_metaroles(
        for => $args{for_class},
        class_metaroles => {
            class => ['OpenXPKI::Server::API2::CommandMetaClassTrait'],
        },
    );
    # 2. apply a role that marks it as a command and adds some functions
    # NOTE: Without on_scope_end() the role would be applied immediately when
    # the Perl compiler parses the importing classes' "use" statement. Methods
    # required by the role would not yet be defined. on_scope_end() defers that.
    # The solution was kindly suggested by mst on IRC.
    on_scope_end { Moose::Util::apply_all_roles($args{for_class}, 'OpenXPKI::Server::API2::CommandRole') };

    return $importing_class_meta;
}

sub api {
    my ($meta, $method_name, $params, $code_ref) = @_;

    $meta->add_method($method_name => $code_ref);

    my $param_metaclass = Moose::Meta::Class->create(
        join("::", $meta->name, "${method_name}_ParamObject"),
#        superclasses => ,
#        roles => ,
    );

    for my $param_name (sort keys %{ $params }) {
        # the parameter specs like "isa => ..., required => ..."
        my $param_spec = $params->{$param_name};
        if ($param_spec->{matching}) {
            # FIXME Implement
            delete $param_spec->{matching};
        }
        # add a Moose attribute to the parameter container class
        $param_metaclass->add_attribute($param_name,
            is => 'ro',
            %{ $param_spec },
        );
    }

    $meta->api_param_classes->{$method_name} = $param_metaclass;
}

1;

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
use OpenXPKI::Server::API2::MetaClassCommandTrait;

#
# Export (imported when calling "use OpenXPKI::Server::API2::Command;")
#
Moose::Exporter->setup_import_methods(
    # functions
    with_meta => [ "api" ],
    # other modules
    also => "Moose",
);

# Moose::Exporter calls init_meta() when the package that uses us calls IMPORT().
# $args{for_class} contains the metaclass of the class that imports us.
sub init_meta {
    shift; # our class name
    my %args = @_;

    Moose->init_meta(%args);

    # Modify the class that imports us:
    # 1. change the classes' metaclass to be able to use the api_param_classes() HashRef
    Moose::Util::MetaRole::apply_metaroles(
        for => $args{for_class},
        class_metaroles => {
            class => ['OpenXPKI::Server::API2::MetaClassCommandTrait'],
        },
    );

    # 2. apply a role that marks it as a command and adds some functions
    # NOTE: Without on_scope_end() the role would be applied immediately when
    # the Perl compiler parses the importing classes' "use" statement. Methods
    # required by the role would not yet be defined. on_scope_end() defers that.
    # The solution was kindly suggested by mst on IRC.
    on_scope_end { Moose::Util::apply_all_roles($args{for_class}, 'OpenXPKI::Server::API2::CommandRole') };
}

=head1 Imported functions

The following functions are imported into the package that uses
C<OpenXPKI::Server::API2::Command>.

=head2 api

Define an API command including input parameter types.

Example:

    api "givetheparams" => {
        name => { isa => 'Str', matching => qr/^(?!Donald).*/, required => 1 },
        size => { isa => 'Int', matching => sub { $_ > 0 } },
    } => sub {
        my ($self, $param_obj) = @_;
        return {
            name => $param_obj->name,
            size => $param_obj->size,
        };
    };

Note that this can be written as (except for the dots obviously)

    api(
        "givetheparams",
        {
            name => ...
            size => ...
        },
        sub {
            my ($self, $param_obj) = @_;
            return { ... };
        }
    );

B<Parameters>

=over

=item * C<$name> - name of the API command

=item * C<$params> - I<HashRef> containing the parameter specifications. Keys
are the parameter names and values are I<HashRefs> with options.

Allows the same options as Moose's I<has> keyword (i.e. I<isa>, I<required> etc.)
plus the following ones:

=over

=item * C<matching> - I<Regexp> or I<CodeRef> that matches if
L<TRUE|perldata/"Scalar values"> value is returned.

=back

=item * C<$function> - I<CodeRef> with the command implementation. On invocation
it gets passed two parameters:

=over

=item * C<$self> - the instance of the command class (that called C<api>).

=item * C<$param_obj> - a parameter data object with Moose attributes that follow
the specifications in I<$params> above.

=back

=back

=cut
sub api {
    my ($meta, $method_name, $params, $code_ref) = @_;

    # Simply add a method of the given name to the calling class
    $meta->add_method($method_name => $code_ref);

    # Create a class that will hold the parameter values
    my $param_metaclass = Moose::Meta::Class->create(
        join("::", $meta->name, "${method_name}_ParamObject"),
#        superclasses => ,
#        roles => ,
    );

    # Add API command parameters to the newly created class as Moose attributes
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

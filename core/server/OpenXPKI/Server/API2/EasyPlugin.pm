package OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::EasyPlugin - Define an OpenXPKI API plugin

=cut

# CPAN modules
use Moose ();
use Moose::Exporter;

# Project modules
use OpenXPKI::Server::API2::EasyPluginRole;
use OpenXPKI::Server::API2::EasyPluginMetaClassTrait;


=head1 DESCRIPTION

To define a new API plugin simply say:

    package OpenXPKI::Server::API2::Plugin::MyTopic::MyActions;
    use OpenXPKI::Server::API2::EasyPlugin;

    command "aaa" => {
        # parameters
    } => sub {
        # actions
        ...
        $self->api->another_command();
        ...
    };

This will modify your package as follows:

=over

=item * imports C<Moose> (i.e. adds "use Moose;" so you don't have to do it)

=item * provides the L</command> keyword (just an imported sub really) to
define API commands

=item * applies the Moose role L<OpenXPKI::Server::API2::EasyPluginRole>

=item * applies the Moose metaclass role (aka. "trait")
L<OpenXPKI::Server::API2::EasyPluginMetaClassTrait>

=back

=cut
Moose::Exporter->setup_import_methods(
    also => [ "Moose" ],
    with_meta => [ "command" ],
    base_class_roles => [ "OpenXPKI::Server::API2::EasyPluginRole" ],
    class_metaroles => {
        class => [ 'OpenXPKI::Server::API2::EasyPluginMetaClassTrait' ],
    },
);


=head1 KEYWORDS (imported functions)

The following functions are imported into the package that uses
C<OpenXPKI::Server::API2::EasyPlugin>.

=head2 command

Define an API command including input parameter types.

Example:

    command "givetheparams" => {
        name => { isa => 'Str', matching => qr/^(?!Donald).*/, required => 1 },
        size => { isa => 'Int', matching => sub { $_ > 0 } },
    } => sub {
        my ($self, $po) = @_;

        $po->name("The genious ".$po->name) if $po->has_name;

        if ($po->has_size) {
            $self->some_helper($po->size);
            $po->clear_size; # unset the attribute
        }

        $self->process($po);
    };

Note that this can be written as (except for the dots obviously)

    command(
        "givetheparams",
        {
            name => ...
            size => ...
        },
        sub {
            my ($self, $po) = @_;
            return { ... };
        }
    );

You can access the API via C<$self-E<gt>api> to call another command.

B<Parameters>

=over

=item * C<$command_name> - name of the API command

=item * C<$params> - I<HashRef> containing the parameter specifications. Keys
are the parameter names and values are I<HashRefs> with options.

Allows the same options as Moose's I<has> keyword (i.e. I<isa>, I<required> etc.)
plus the following ones:

=over

=item * C<matching> - I<Regexp> or I<CodeRef> that matches if
L<TRUE|perldata/"Scalar values"> value is returned.

=back

You can use all Moose types (I<Str>, I<Int> etc) plus OpenXPKI's own types
defined in L<OpenXPKI::Server::API2::Types> (C<OpenXPKI::Server::API2>
automatically imports them).

=item * C<$function> - I<CodeRef> with the command implementation. On invocation
it gets passed two parameters:

=over

=item * C<$self> - the instance of the command class (that called C<api>).

=item * C<$po> - a parameter data object with Moose attributes that follow
the specifications in I<$params> above.

For each attribute two additional methods are available on the C<$po>:
A clearer named C<clear_*> to clear the attribute and a predicate C<has_*> to
test if it's set. See L<Moose::Manual::Attributes/Predicate and clearer methods>
if you don't know what that means.

=back

=back

=cut
sub command {
    my ($meta, $command_name, $params, $code_ref) = @_;

    # Add a method of the given name to the calling class
    $meta->add_method($command_name, $code_ref);

    # Add a parameter class (see OpenXPKI::Server::API2::EasyPluginMetaClassTrait)
    $meta->add_param_specs($command_name, $params);
}

1;

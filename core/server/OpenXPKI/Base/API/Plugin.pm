package OpenXPKI::Base::API::Plugin;

=head1 NAME

OpenXPKI::Base::API::Plugin - Define an OpenXPKI API plugin

=cut

# CPAN modules
use Moose ();
use Moose::Exporter;

=head1 DESCRIPTION

B<Not intended for direct use> - C<use OpenXPKI -plugin> instead:

    package OpenXPKI::Server::API2::Plugin::MyTopic::MyActions;
    use OpenXPKI -plugin;

    command "aaa" => {
        # parameters
    } => sub {
        # actions
        ...
        $self->api->another_command();
        ...
    };

If no namespace is specified in a plugin class the commands are assigned to
the default namespace of the API.

It does not seem to be possible to set a custom base class for your
plugin, but you can instead easily add another role to it:

    package OpenXPKI::Server::API2::Plugin::MyTopic::MyActions;
    use OpenXPKI -plugin;

    with "OpenXPKI::Server::API2::Plugin::MyTopic::Base";

C<use OpenXPKI -plugin> will modify your package as follows:

=over

=item * adds C<use Moose;>

=item * provides the L</command> keyword to define API commands

=item * applies the Moose role L<OpenXPKI::Base::API::PluginRole>

=item * applies the Moose metaclass role (aka. "trait")
L<OpenXPKI::Base::API::PluginMetaClassTrait>

=back

=cut
Moose::Exporter->setup_import_methods(
    with_meta => [ 'command', 'protected_command' ],
    base_class_roles => [ 'OpenXPKI::Base::API::PluginRole' ],
    class_metaroles => {
        class => [ 'OpenXPKI::Base::API::PluginMetaClassTrait' ],
    },
);


=head1 KEYWORDS (imported functions)

The following functions are imported into the package that uses
C<OpenXPKI::Base::API::Plugin>.

=head2 command

Define an API command including input parameter types.

Example:

    command 'givetheparams' => {
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
        'givetheparams',
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

=item * C<$command> - name of the API command

=item * C<$params> - I<HashRef> containing the parameter specifications. Keys
are the parameter names and values are I<HashRefs> with options.

Allows the same options as Moose's I<has> keyword (i.e. I<isa>, I<required> etc.)
plus the following ones:

=over

=item * C<matching> - I<Regexp> or I<CodeRef> that matches if
L<TRUE|perldata/"Scalar values"> value is returned.

=back

You can use all Moose types (I<Str>, I<Int> etc) plus OpenXPKI's own types
defined in L<OpenXPKI::Types> (they are automatically imported by
C<use OpenXPKI -plugin>).

=item * C<$code_ref> - I<CodeRef> with the command implementation. On invocation
it gets passed two parameters:

=over

=item * C<$self> - the instance of the command class (that called C<api>).

=item * C<$po> - a parameter data object with Moose attributes that follow
the specifications in I<$params> above.

For each attribute two additional methods are available on the C<$po>:
A clearer named C<clear_*> to clear the attribute and a predicate C<has_*> to
test if it's set. See L<Moose::Manual::Attributes/Predicate and clearer methods>
if you don't know what that means.

When using any type that has a coercion defined the C<coerce =E<gt> 1> option
will automatically be set (by
L<OpenXPKI::Base::API::PluginMetaClassTrait/add_param_specs>):

    command "doit" => {
        types => { isa => 'ArrayRefOrCommaList' }, # will set coerce => 1
    } => sub {
        my ($self, $params) = @_;
        print join(", ", @{ $params->types }), "\n";
    };

=back

=back

=cut
sub command {
    my ($meta, $command, $params, $code_ref) = @_;

    _command($meta, $command, $params, $code_ref, 0);
}

=head2 protected_command

Define a protected API command. All parameters are equivalent to L</command>.

Commands are only protected if L<OpenXPKI::Base::API::APIRole/enable_protection> is
set to TRUE. In this case they can only be called by passing
C<protected_call =E<gt> 1> to L<OpenXPKI::Base::API::APIRole/dispatch>.


=cut
sub protected_command {
    my ($meta, $command, $params, $code_ref) = @_;

    _command($meta, $command, $params, $code_ref, 1);
}

#
sub _command {
    my ($meta, $command, $params, $code_ref, $is_protected) = @_;

    $meta->add_method($command, $code_ref);         # Add method to calling class (Moose::Meta::Class)
    $meta->param_specs($command, $params);          # Add parameter specifications (OpenXPKI::Base::API::PluginMetaClassTrait)
    $meta->is_protected($command, $is_protected);   # Set protection flag (OpenXPKI::Base::API::PluginMetaClassTrait)
}

1;
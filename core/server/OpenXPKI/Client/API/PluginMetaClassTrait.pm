package OpenXPKI::Client::API::PluginMetaClassTrait;
use OpenXPKI -role;

# CPAN modules
use Moose::Util ();

=head1 NAME

OpenXPKI::Client::API::PluginMetaClassTrait - Moose metaclass role (aka.
"trait") for client side command plugins

=head1 DESCRIPTION

B<Not intended for direct use> - this is part of the internal API magic.

=METHODS

=head2 set_command_behaviour

B<Parameters>

=over

=item * C<$...> - ...

=back

=cut
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
                hint => 'hint_realm',
            }
        );
    }

    # TODO Implement command_setup(protected => 1) or replace it with protected_command
}

1;

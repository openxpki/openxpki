package OpenXPKI::Client::API::Plugin;

=head1 NAME

OpenXPKI::Client::API::Plugin - Additional API plugin behaviour for
client side command plugins

=cut

# CPAN modules
use Moose ();
use Moose::Exporter;

=head1 DESCRIPTION

B<Not intended for direct use> - C<use OpenXPKI -client_plugin> instead.

=cut

Moose::Exporter->setup_import_methods(
    with_meta => [ 'command_setup' ],
    base_class_roles => [ 'OpenXPKI::Client::API::PluginRole' ],
    class_metaroles => {
        class => [ 'OpenXPKI::Client::API::PluginMetaClassTrait' ],
    },
);

sub command_setup :prototype(@) {
    my ($meta, @args) = @_;

    my $caller_package = caller(1);
    $meta->set_command_behaviour(caller => $caller_package, @args);
}

1;
package OpenXPKI::Client::API::Command::config::footprint;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::config::footprint

=head1 DESCRIPTION

Shows the footprint of the B<running> OpenXPKI configuration.

The footprint provides information about the inner complexity of your
installation.

=cut

command "footprint" => {
} => sub ($self, $param) {

    my $footprint = $self->run_protected_command('get_license_info');
    return $footprint->params->{total};

};

__PACKAGE__->meta->make_immutable;



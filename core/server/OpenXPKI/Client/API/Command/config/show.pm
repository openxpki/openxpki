package OpenXPKI::Client::API::Command::config::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::config::show

=head1 DESCRIPTION

Show information of the B<running> OpenXPKI configuration.

If called without parameters, prints the information found at
I<system.version> and the configuration digest.

Provide a config path (key seperated by a dot, e.g.
I<system.database.main>) to dump the configuration found at this
node.

=cut

command "show" => {
    path => { isa => 'Str', label => 'Path to dump' },
} => sub ($self, $param) {


    if ($param->has_path) {
        return $self->run_protected_command('config_show', { path => $param->path });
    } else {
        my $digest = substr($self->run_protected_command('config_show')->params->{digest},0,8);
        my $res = $self->run_protected_command('version');
        return {
            %{$res->params()},
            version => $digest,
        };
    }

};

__PACKAGE__->meta->make_immutable;



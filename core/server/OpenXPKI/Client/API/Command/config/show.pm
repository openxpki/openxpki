package OpenXPKI::Client::API::Command::config::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::config::show

=head1 DESCRIPTION

Show information from the B<running> OpenXPKI configuration.

Without parameters returns the version information (from
C<system.version>) together with the configuration digest.

When a path is given, dumps the configuration tree at that node.
=cut

command "show" => {
    path => { isa => 'Str', label => 'Dot-separated config path to dump (e.g. system.database.main)' },
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



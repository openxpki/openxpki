package OpenXPKI::Client::API::Command::config::show;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    protected => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::config::show

=head1 SYNOPSIS

Show information of the (running) OpenXPKI configuration

=cut

command "show" => {
    path => { isa => 'Str', label => 'Path to dump' },
} => sub ($self, $param) {

    my $params = {
         $param->has_path ? (path => $param->path) : (),
    };
    my $res = $self->run_protected_command('config_show', $params);
    return $res;

};

__PACKAGE__->meta->make_immutable;



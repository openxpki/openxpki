package OpenXPKI::Client::API::Command::config::show;
use OpenXPKI -plugin;

with 'OpenXPKI::Client::API::Command::config';
set_namespace_to_parent;

with 'OpenXPKI::Client::API::Command::Protected';

=head1 NAME

OpenXPKI::Client::API::Command::config::show;

=head1 SYNOPSIS

Show information of the (running) OpenXPKI configuration

=cut

command "show" => {
    path => { isa => 'Str', label => 'Path to dump' },
} => sub ($self, $param) {

    my $params;
    if (my $path = $param->path) {
        $params->{path} = $path;
    }
    my $res = $self->rawapi->run_protected_command('config_show', $params);
    return $res;

};

__PACKAGE__->meta->make_immutable;



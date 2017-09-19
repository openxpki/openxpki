package OpenXPKI::Server::API2::EasyPluginRole;
=head1 Name

OpenXPKI::Server::API2::EasyPluginRole - Role for easy API plugins

=cut
use Moose::Role;

with 'OpenXPKI::Server::API2::PluginRole';

sub commands {
    my $self = shift;
    return [ $self->meta->command_list ]; # provided by OpenXPKI::Server::API2::EasyPluginMetaClassTrait
}

sub execute {
    my ($self, $command, $params) = @_;

    my $param_obj = $self->meta->new_param_object($command, $params); # provided by OpenXPKI::Server::API2::EasyPluginMetaClassTrait
    return $self->$command($param_obj);
}

1;

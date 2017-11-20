package OpenXPKI::Server::API2::EasyPluginRole;
=head1 Name

OpenXPKI::Server::API2::EasyPluginRole - Role for easy API plugins

=cut
use Moose::Role;

with 'OpenXPKI::Server::API2::PluginRole';

=head1 DESCRIPTION

B<Not intended for direct use.> Please C<use OpenXPKI::Server::API2::EasyPlugin;>
instead.

This role implements the methods required by L<OpenXPKI::Server::API2::PluginRole>
by accessing the metadata that is provided by meta class role
L<OpenXPKI::Server::API2::EasyPluginMetaClassTrait>.

Therefore it expects the consuming class to also have
L<OpenXPKI::Server::API2::EasyPluginMetaClassTrait> applied.

=head1 METHODS

=head2 commands

Returns a list of the commands that the

=cut
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

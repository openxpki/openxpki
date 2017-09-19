package OpenXPKI::Server::API2::EasyPluginRole;
=head1 Name

OpenXPKI::Server::API2::EasyPluginRole - Role for easy API plugins

=cut
use Moose::Role;

with 'OpenXPKI::Server::API2::PluginRole';

sub blah {}
1;

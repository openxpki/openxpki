package OpenXPKI::Server::API2::PluginRole;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::Server::API2::PluginRole - Base role for API plugins

=head1 DESCRIPTION

B<Not intended for direct use.> Please C<use OpenXPKI::Server::API2::EasyPlugin;>
instead.

This role accesses the metadata that is provided by meta class role
L<OpenXPKI::Server::API2::PluginMetaClassTrait>.

Therefore it expects the consuming class to also have
L<OpenXPKI::Server::API2::PluginMetaClassTrait> applied.

=head1 ATTRIBUTES

=head2 api

Instance of the L<API autoloader|OpenXPKI::Server::API2::Autoloader>. Will be
set automatically.

=cut
has api => (
    is => 'ro',
    isa => 'OpenXPKI::Server::API2::Autoloader',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->rawapi->autoloader },
);

=head2 rawapi

Instance of the L<raw API|OpenXPKI::Server::API2>. Will be injected by the API
upon instantiation.

=cut
has rawapi => (
    is => 'ro',
    isa => 'OpenXPKI::Server::API2',
    required => 1,
);

=head1 METHODS

=cut

sub BUILD {} # overridden by consuming class' BUILD method (if any)
after BUILD => sub ($self, $args) {
    # ensure we have the meta class methods provided by OpenXPKI::Server::API2::PluginMetaClassTrait
    die sprintf $self->meta->name . '\'s meta class does not consume OpenXPKI::Server::API2::PluginMetaClassTrait'
      unless $self->meta->meta->does_role('OpenXPKI::Server::API2::PluginMetaClassTrait');
};

=head2 commands

Returns the list of commands that the plugin package contains.

=cut
sub commands ($self) {
    return [ $self->meta->command_list ]; # provided by OpenXPKI::Server::API2::PluginMetaClassTrait
}

=head2 execute

Executes the given API command.

=cut
signature_for execute => (
    method => 1,
    positional => [ 'Str', 'HashRef' ],
);
sub execute ($self, $command, $params) {
    my $param_obj = $self->meta->new_param_object($command, $params); # provided by OpenXPKI::Server::API2::PluginMetaClassTrait
    return $self->$command($param_obj);
}

1;

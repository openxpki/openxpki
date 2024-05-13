package OpenXPKI::Server::API2::PluginRole;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::Server::API2::PluginRole - Base role for API plugins

=head1 DESCRIPTION

B<Not intended for direct use.> Please C<use OpenXPKI -plugin>
instead.

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

1;

package OpenXPKI::Base::API::PluginRole;
use OpenXPKI -role;

=head1 NAME

OpenXPKI::Base::API::PluginRole - Base role for API plugins

=head1 DESCRIPTION

B<Not intended for direct use> - this is part of the internal API magic.

=head1 ATTRIBUTES

=head2 api

Readonly: instance of the L<API autoloader|OpenXPKI::Base::API::Autoloader>.

=cut
has api => (
    is => 'ro',
    isa => 'OpenXPKI::Base::API::Autoloader',
    init_arg => undef,
    lazy => 1,
    default => sub { shift->rawapi->autoloader },
);

=head2 rawapi

Instance of the L<raw API|OpenXPKI::Base::API::APIRole>. Injected by
L<OpenXPKI::Base::API::APIRole/dispatch>.

=cut
has rawapi => (
    is => 'ro',
    does => 'OpenXPKI::Base::API::APIRole',
    required => 1,
);

1;

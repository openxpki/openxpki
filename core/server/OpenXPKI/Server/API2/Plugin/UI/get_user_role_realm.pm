package OpenXPKI::Server::API2::Plugin::UI::get_user_role_realm;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::UI::get_user_role_realm

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_user

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_user" => {
} => sub {
    my ($self, $params) = @_;
    return CTX('session')->data->user;
};

=head2 get_role

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_role" => {
} => sub {
    my ($self, $params) = @_;
    return CTX('session')->data->role;
};

=head2 get_pki_realm

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_pki_realm" => {
} => sub {
    my ($self, $params) = @_;
    return CTX('session')->data->pki_realm;
};

__PACKAGE__->meta->make_immutable;

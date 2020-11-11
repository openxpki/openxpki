package OpenXPKI::Server::API2::Plugin::Secret::clear_secret;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Secret::clear_secret

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 clear_secret

Purge the given secret group.

B<Parameters>

=over

=item * C<secret> I<Str> - name of the secret (group). Required.

=back

=cut
command "clear_secret" => {
    secret => { isa => 'AlphaPunct', required => 1, },
} => sub {
    my ($self, $params) = @_;
    CTX('log')->audit('system')->info("clearing secret", { group => $params->secret });
    CTX('crypto_layer')->clear_secret($params->secret);
    return 1;
};

__PACKAGE__->meta->make_immutable;

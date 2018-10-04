package OpenXPKI::Server::API2::Plugin::Secret::is_secret_complete;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Secret::is_secret_complete

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 is_secret_complete

Returns 1 if the given secret group is complete, i.e. all necessary parts
are set/loaded.

B<Parameters>

=over

=item * C<secret> I<Str> - name of the secret (group). Required.

=back

=cut
command "is_secret_complete" => {
    secret => { isa => 'AlphaPunct', required => 1, },
} => sub {
    my ($self, $params) = @_;
    return CTX('crypto_layer')->is_secret_group_complete($params->secret);
};

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Cert::is_local_entity;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::is_local_entity

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head1 COMMANDS

=head2 is_local_entity

Check if the given certificate identifier is a local entity.

Returns C<1> if the certificate has C<req_key> set and the realm matches.

Returns C<undef> if the certificate was not found at all and C<0> if the
certificate is not an entity in the given realm.

B<Parameters>

=over

=item * C<identifier> I<Str>

=item * C<pki_realm> I<Str>

PKI realm. Optional, default: current realm. If set to C<"_any"> all realms are checked.

=back

=cut

command "is_local_entity" => {
    identifier => { isa => 'Base64', required => 1, },
    pki_realm =>  { isa => 'AlphaPunct', default => sub { CTX('session')->data->pki_realm } },
} => sub {
    my ($self, $params) = @_;

    my $dbi = CTX('dbi');

    my $identifier = $params->identifier;
    my $pki_realm  = $params->pki_realm;

    ##! 2: "Fetching certificate from database"
    my $cert = $dbi->select_one(
        columns => [ 'req_key', 'pki_realm' ],
        from => 'certificate',
        where => { 'identifier' => $identifier },
    );

    # nothing found
    return unless($cert);

    # not a local entity at all
    return 0 unless($cert->{req_key});

    # matches realm
    return 1 if ($cert->{pki_realm} eq $pki_realm );

    # any realm requested
    return 1 if ($pki_realm eq '_any');

    # local entity but from other realm
    return 0;

};

__PACKAGE__->meta->make_immutable;

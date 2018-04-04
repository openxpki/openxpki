package OpenXPKI::Server::API2::Plugin::Cert::get_cert_identifier;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert_identifier

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_cert_identifier

Calculates the certificate identifier (Base64 encoded SHA1 sum of the
certificate body) and returns it.

B<Parameters>

=over

=item * C<cert> I<Str> - PEM encoded certificate data

=back

=cut
command "get_cert_identifier" => {
    cert => { isa => 'PEMCert', required => 1, },
} => sub {
    my ($self, $params) = @_;
    my $cert = $params->cert;
    ##! 64: 'cert: ' . $cert

    my $x509 = OpenXPKI::Crypto::X509->new(
        DATA  => $cert,
        TOKEN => CTX('api')->get_default_token,
    );

    my $identifier = $x509->get_identifier;
    ##! 4: 'identifier: ' . $identifier

    return $identifier;
};

__PACKAGE__->meta->make_immutable;

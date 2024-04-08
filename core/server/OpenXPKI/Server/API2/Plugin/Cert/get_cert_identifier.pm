package OpenXPKI::Server::API2::Plugin::Cert::get_cert_identifier;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_cert_identifier

=cut

use Digest::SHA qw(sha1_base64);
use MIME::Base64;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Types;



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

    $cert =~ m{-----BEGIN[^-]*CERTIFICATE-----(.+)-----END[^-]*CERTIFICATE-----}xms;
    my $cert_identifier = sha1_base64(decode_base64($1));
    ## RFC 3548 URL and filename safe base64
    $cert_identifier =~ tr/+\//-_/;
    ##! 4: 'identifier: ' . $identifier

    return $cert_identifier;

};

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Crypto::get_key_identifier_from_data;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::get_key_identifier_from_data

=cut

# Core modules
use Digest::SHA qw(sha1_hex);

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

# CPAN modules
use Crypt::PKCS10 1.10;


=head1 COMMANDS

=head2 get_key_identifier_from_data

returns the key identifier (sha1 hash of the public key bit string) of the
given data as string, uppercased hex with colons.

=over

=item DATA

Data, encoded as given by FORMAT parameter.

=item FORMAT

* PKCS10: PEM encoded PKCS10 block

=back

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_key_identifier_from_data" => {
    data   => { isa => 'PEM', required => 1, },
    format => { isa => 'Str', matching => qr/( \A (PKCS10) \z )/msx, required => 1, },
} => sub {
    my ($self, $params) = @_;

    # we currently only support PKCS10

    Crypt::PKCS10->setAPIversion(1);
    my $decoded = Crypt::PKCS10->new($params->data, ignoreNonBase64 => 1, verifySignature => 0)
        or OpenXPKI::Exception->throw(message => 'Unable to parse data in get_key_identifier_from_data');

    return uc(
        join ':', (
            unpack '(A2)*', sha1_hex(
                $decoded->{certificationRequestInfo}{subjectPKInfo}{subjectPublicKey}[0]
            )
        )
    );
};

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Cert::get_profile_for_cert;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::get_profile_for_cert

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 get_profile_for_cert

Returns the name of the profile used during the certificate request.
Supported argument is IDENTIFIER which is required.

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "get_profile_for_cert" => {
    identifier => { isa => 'Base64', required => 1, },
} => sub {
    my ($self, $params) = @_;

    ##! 2: "initialize arguments"
    my $identifier = $params->identifier;

    my $result = CTX('dbi')->select_one(
        from_join => 'certificate req_key=req_key csr',
        columns => [ 'csr.profile' ],
        where => { 'certificate.identifier' => $identifier },
    )
        or OpenXPKI::Exception->throw(
            message => 'Could not determine profile for given certificate (no CSR found)',
            params => { identifier => $identifier },
        );

    return $result->{'profile'};
};

__PACKAGE__->meta->make_immutable;

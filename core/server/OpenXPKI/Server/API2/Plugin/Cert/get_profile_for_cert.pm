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
Supported argument is identifier which is required. If no profile can be
determined, undef is returned unless raise_exception is set.

B<Parameters>

=over

=item * identifier

=item * raise_exception, Bool

=back

=cut
command "get_profile_for_cert" => {
    identifier => { isa => 'Base64', required => 1, },
    raise_exception => => { isa => 'Bool', default=> 0, },
} => sub {
    my ($self, $params) = @_;

    ##! 2: "initialize arguments"
    my $identifier = $params->identifier;

    my $result = CTX('dbi')->select_one(
        from_join => 'certificate req_key=req_key csr',
        columns => [ 'csr.profile' ],
        where => { 'certificate.identifier' => $identifier },
    );

    if (!$result) {
        CTX('log')->system()->warn('No profile found for '.$identifier);
        OpenXPKI::Exception->throw(
            message => 'Could not determine profile for given certificate (no CSR found)',
            params => { identifier => $identifier },
        ) if ($params->raise_exception);
        return;
    }

    return $result->{'profile'};
};

__PACKAGE__->meta->make_immutable;

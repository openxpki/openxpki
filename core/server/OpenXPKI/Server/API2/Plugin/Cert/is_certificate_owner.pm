package OpenXPKI::Server::API2::Plugin::Cert::is_certificate_owner;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Cert::is_certificate_owner

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 is_certificate_owner

Returns C<true> if the given user is the owner of the specified certificate,
C<false> if not and C<undef> if the ownership could not be determined.

Requires a certificate identifier (IDENTIFIER) and user (USER). User is
optional and will default to the session user if not given. Checks if
USER is the owner of the certificate, based on the formerly recorded meta
information.

B<Parameters>

=over

=item * C<XXX> I<Bool> - XXX. Default: XXX

=back

=cut
command "is_certificate_owner" => {
    identifier => { isa => 'Base64', required => 1, },
    user       => { isa => 'Str', },
} => sub {
    my ($self, $params) = @_;

    my $user = $params->has_user ? $params->user : CTX('session')->data->user;

    my $result = CTX('dbi')->select_one(
        from => 'certificate_attributes',
        columns => [ 'attribute_value' ],
        where => {
            identifier => $params->identifier,
            attribute_contentkey => 'system_cert_owner',
        },
    );

    return undef unless $result;

    ##! 16: "compare $user ?= " . $result->{attribute_value}
    return ($result->{attribute_value} eq $user);
};

__PACKAGE__->meta->make_immutable;

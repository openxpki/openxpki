package OpenXPKI::Server::API2::Plugin::Profile::list_supported_san;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Profile::list_supported_san

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head2 list_supported_san

Return a HashRef of all supported SAN attributes.

Keys are all lowercase while the value is in correct CamelCaseing for OpenSSL.

=cut
command "list_supported_san" => {
} => sub {
    my ($self, $params) = @_;

    my %san_names = map { lc($_) => $_ } ('email','URI','DNS','RID','IP','dirName','otherName','GUID','UPN');

    return \%san_names;
};

__PACKAGE__->meta->make_immutable;

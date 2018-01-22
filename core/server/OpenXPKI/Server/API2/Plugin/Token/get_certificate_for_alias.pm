package OpenXPKI::Server::API2::Plugin::Token::get_certificate_for_alias;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::get_certificate_for_alias

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;

=head2 get_certificate_for_alias

Find the certificate for the given alias.

Returns a I<HashRef> the certificate:

    {
        data => '...',       # PEM encoded certificate
        subject => '...',
        identifier => '...',
        notbefore => '...',  # certificate validity (UNIX epoch timestamp)
        notafter => '...',   # certificate validity (UNIX epoch timestamp)
    }

Validity dates are the real certificate dates.

B<Parameters>

=over

=item * C<alias> I<Str> - certificate alias (required)

=back

=cut
command "get_certificate_for_alias" => {
    alias => { isa => 'AlphaPunct', required => 1, },
} => sub {
    my ($self, $params) = @_;

    ##! 32: "Search for alias $params->alias"
    my $cert = CTX('dbi')->select_one(
        from_join => 'certificate identifier=identifier aliases',
        columns => [
            'certificate.data',
            'certificate.subject',
            'certificate.identifier',
            'certificate.notbefore',
            'certificate.notafter',
        ],
        where => {
            'aliases.alias'     => $params->alias,
            'aliases.pki_realm' => CTX('session')->data->pki_realm,
        }
    )
    or OpenXPKI::Exception->throw (
        message => 'No certificate found for given alias',
        params => { alias => $params->alias }
    );
    ##! 32: "Found certificate $cert->{subject}"
    ##! 64: "Found certificate " . Dumper $cert
    return {
        data        => $cert->{data},
        subject     => $cert->{subject},
        identifier  => $cert->{identifier},
        notbefore   => $cert->{notbefore},
        notafter    => $cert->{notafter},
    };
};

__PACKAGE__->meta->make_immutable;

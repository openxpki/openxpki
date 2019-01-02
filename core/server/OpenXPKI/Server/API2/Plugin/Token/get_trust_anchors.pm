package OpenXPKI::Server::API2::Plugin::Token::get_trust_anchors;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::get_trust_anchors

=head1 COMMANDS

=cut

# Project modules
use Data::Dumper;
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

=head2 get_trust_anchors

Get the trust anchors as defined at the given config path.

Result is an I<ArrayRef> of certificate identifiers.

B<Parameters>

=over

=item * C<path> I<Str> - configuration path, must point to a config node which
has at least these two child nodes: C<realm> (list of realms), C<cacert> (list
if extra certificate identifiers):

    path:
        realm:
         - ca-one
        cacert:
         - list of extra cert identifiers

=back

=cut
command "get_trust_anchors" => {
    path => { isa => 'AlphaPunct|ArrayRef', required => 1, },
} => sub {
    my ($self, $params) = @_;

    my $path = $params->path;

    if (!ref $path) {
        my @t = split /\./, $path;
        $path = \@t;
    }

    ##! 8: 'Anchor path ' . Dumper $path
    my $config = CTX('config');

    my @trust_certs =  $config->get_scalar_as_list([ @$path, 'cacert']);
    my @trust_realms = $config->get_scalar_as_list([ @$path, 'realm']);

    ##! 8: 'Trusted Certs ' . Dumper \@trust_certs
    ##! 8: 'Trusted Realm ' . Dumper \@trust_realms

    my @trust_anchors;
    @trust_anchors = @trust_certs if (@trust_certs);

    for my $realm (@trust_realms) {
        ##! 16: 'Load ca signers from realm ' . $realm
        next unless $realm;
        my $ca_certs = CTX('api')->list_active_aliases({ TYPE => 'certsign', PKI_REALM => $realm });
        ##! 16: 'ca cert in realm ' . Dumper $ca_certs
        if (!$ca_certs) { next; }
        push @trust_anchors, map { $_->{IDENTIFIER} } @{$ca_certs};
    }

   return \@trust_anchors;
};

__PACKAGE__->meta->make_immutable;

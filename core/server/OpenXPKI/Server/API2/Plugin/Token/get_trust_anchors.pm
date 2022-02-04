package OpenXPKI::Server::API2::Plugin::Token::get_trust_anchors;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Token::get_trust_anchors

=head1 COMMANDS

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );

=head2 get_trust_anchors

Get the trust anchors as defined at the given config path.

The config path must have at least one of this keys defined, where the
value is either a single item or a list of items of the defined type.

=over

=item realm

Adds all active issuing ca certificates from the given realm as trust
anchors, so all certificates issued from this realm will be accepted.

=item cacert

A certificate identifier to use as trusted issuer. The certificate must
exist in the database but do not need to be in any particular realm or
referenced in a token configuration.

=item alias

Name of an alias B<group> from the aliases table, the alias items are
read from the current realm or, if no items are found, from the global
realm. Validity dates of the alias table are used.

=back

Result is an I<ArrayRef> of certificate identifiers.

B<Parameters>

=over

=item * C<path> I<Str> - configuration path, must point to a config node which
has at least one of the defining child nodes:

    path:
        realm:
         - democa
        cacert:
         - list of extra cert identifiers
        alias:
         - names of alias groups

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
    my @trust_groups = $config->get_scalar_as_list([ @$path, 'alias']);

    ##! 8: 'Trusted Certs ' . Dumper \@trust_certs
    ##! 8: 'Trusted Realm ' . Dumper \@trust_realms
    ##! 8: 'Trusted Groups ' . Dumper \@trust_groups

    my @trust_anchors;
    @trust_anchors = @trust_certs if (@trust_certs);

    for my $realm (@trust_realms) {
        ##! 16: 'Load ca signers from realm ' . $realm
        next unless $realm;
        my $ca_certs = $self->api->list_active_aliases( type => 'certsign', pki_realm => $realm );
        ##! 16: 'ca cert in realm ' . Dumper $ca_certs
        push @trust_anchors, map { $_->{identifier} } @{$ca_certs};
    }

    my $pki_realm = $self->api->get_pki_realm;
    for my $alias (@trust_groups) {
        ##! 16: 'Load trust group '.$alias
        next unless $alias;
        my $ca_certs = $self->api->list_active_aliases( group => $alias, pki_realm => $pki_realm );
        # look in global realm
        if (!scalar @{$ca_certs}) {
            ##! 32: 'Alias group not found in realm - lookup global'
            $ca_certs = $self->api->list_active_aliases( group => $alias, pki_realm => '_global' );
        }
        ##! 16: 'ca cert in realm ' . Dumper $ca_certs
        push @trust_anchors, map { $_->{identifier} } @{$ca_certs};
    }



   return \@trust_anchors;
};

__PACKAGE__->meta->make_immutable;

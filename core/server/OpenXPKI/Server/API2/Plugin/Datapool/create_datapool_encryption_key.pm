package OpenXPKI::Server::API2::Plugin::Datapool::create_datapool_encryption_key;
use OpenXPKI::Server::API2::EasyPlugin;

with 'OpenXPKI::Server::API2::Plugin::Datapool::Util';

=head1 NAME

OpenXPKI::Server::API2::Plugin::Datapool::create_datapool_encryption_key

=cut

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 create_datapool_encryption_key


Example:

    CTX('api2')->create_datapool_encryption_key(
        pki_realm => $pki_realm,
        dynamic_iv => 1,
        expiration_date => time + 3600 * 24 * 7,
    );

B<Parameters>

=over

=item * C<pki_realm> I<Str> - PKI realm. Optional, default: current realm

=item * C<expiration_date> I<Int> - UNIX epoch timestamp when the entry shall be
deleted. Optional, default: keep entry infinitely.

=item * C<dynamic-iv> I<Bool> - set to 1 if you wish the entry to be encrypted.
Optional, default: 0

=back

=cut
command "create_datapool_encryption_key" => {
    pki_realm       => { isa => 'AlphaPunct' },
    expiration_date => { isa => 'Int', matching => sub { $_ > time }, },
    dynamic_iv      => { isa => 'Bool', default => 0 },
} => sub {
    my ($self, $params) = @_;

    ##! 32: $params

    my $result = $self->create_realm_encryption_key( %$params );
    ##! 32: 'New datapool key id ' . $result->{KEY_ID}
    ##! 64: $result
    return  $result->{KEY_ID};
};

__PACKAGE__->meta->make_immutable;

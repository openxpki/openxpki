package OpenXPKI::Crypto::Token::Vault;
use OpenXPKI -class;

extends 'OpenXPKI::Crypto::Token';

with 'OpenXPKI::Crypto::Token::Role::Static';

# Project modules
use OpenXPKI::Crypto::VolatileVault;
use OpenXPKI::Server::Context qw( CTX );

=head1 Name

OpenXPKI::Crypto::Token::Vault

=head1 Description

This module manages all cryptographic tokens. You can use it to simply
get tokens and to manage the state of a token.

=head1 Functions

=cut

has '_vault' => (
    is => 'ro',
    isa => 'OpenXPKI::Crypto::VolatileVault',
    builder => '_create_vault',
    lazy => 1,
    predicate => 'is_available',
);

has 'vault_id' => (
    is => 'rw',
    isa => 'Str',
    default => 'unknown',
);

has '_secret' => (
    is => 'ro',
    does => 'OpenXPKI::Crypto::SecretRole',
    required => 1,
    init_arg => 'secret',
);

sub _create_vault {

    my ($self) = @_;

    die "Secret not yet loaded" unless ($self->_secret->is_complete);

    ##! 1: 'creating vault'
    my $literal = uc($self->_secret->get_secret());
    OpenXPKI::Exception->throw (
        message => "Vault requires a 256 bit length secret value encoded in 64 uppercase hex characters "
    ) unless($literal =~ m{\A[0-9A-F]{64}\z});

    # create volatile vault using shared secret
    my $vv = OpenXPKI::Crypto::VolatileVault->new({
        TOKEN => CTX('api2')->get_default_token,
        KEY => $literal,
        IV => undef
    });

    $self->vault_id( $vv->get_key_id({ LONG => 1 }) );
    return $vv;
}


signature_for encrypt => (
    method => 1,
    named => [
        message => 'Str',
    ],
);
sub encrypt ($self, $arg) {

    return unless ($self->_secret->is_complete);

    return $self->_vault->encrypt( $arg->message );
}

signature_for decrypt => (
    method => 1,
    named => [
        message => 'Str',
    ],
);
sub decrypt ($self, $arg) {

    return unless ($self->_secret->is_complete);

    return $self->_vault->decrypt( $arg->message );
}

sub get_key_info {

    my $self = shift;
    return {
        'is_online' => ($self->online ? 1 : 0),
        'vault_id' => $self->vault_id(),
        'key_id' => substr($self->vault_id(), 0, 8),
        'key_alg' => 'aes256',
    }

}

1;

__PACKAGE__->meta->make_immutable;

__END__;

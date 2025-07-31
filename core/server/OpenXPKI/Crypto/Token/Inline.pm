package OpenXPKI::Crypto::Token::Inline;
use OpenXPKI -class;

extends 'OpenXPKI::Crypto::Token';

with 'OpenXPKI::Role::FileUtil';
with 'OpenXPKI::Crypto::Token::Role::Key';

use Crypt::PK::RSA;

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Crypt::X509;

=head1 Name

OpenXPKI::Crypto::Token::Inline

=head1 Description

This module manages all cryptographic tokens. You can use it to simply
get tokens and to manage the state of a token.

=head1 Functions

=cut

has 'name' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'certificate' => (
    is => 'ro',
    isa => 'OpenXPKI::Crypt::X509',
    required => 1,
);

has 'chain' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    default => sub {[]}
);

has 'certificate_file' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    reader => 'get_certificate_file',
    default => sub {
        my $self = shift;
        return $self->fileutil->write_temp_file($self->certificate->pem);
    },
);

has 'certificate_chain_file' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    reader => 'get_certificate_chain_file',
    default => sub {
        my $self = shift;
        return $self->fileutil->write_temp_file(join("\n", $self->certificate->pem, $self->chain->@*));
    },
);

has '_token' => (
    is => 'ro',
    isa => 'Crypt::PK::RSA',
    lazy => 1,
    default => sub {
        my $self = shift;
        return Crypt::PK::RSA->new(\($self->_key), $self->get_passwd() );
    },
);

has '_secret' => (
    is => 'ro',
    does => 'OpenXPKI::Crypto::SecretRole',
    required => 1,
    init_arg => 'secret',
);


signature_for sign => (
    method => 1,
    named => [
        message => 'Str',
        digest => 'Str', { optional => 1, default => 'SHA256' },
        padding => 'Str', { optional => 1, default => 'v1.5' },
        saltlen => 'Str', { optional => 1 },
    ],
);
sub sign ($self, $arg) {

    return unless ($self->_secret->is_complete);

    my @arg = ($arg->message, $arg->digest, $arg->padding);
    if ($arg->padding eq 'pss' && $arg->saltlen) {
        push @arg, $arg->saltlen;
    }
    return $self->_token->sign_message(@arg);
}

signature_for verify => (
    method => 1,
    named => [
        signature => 'Str',
        message => 'Str',
        digest => 'Str', { optional => 1, default => 'SHA256' },
        padding => 'Str', { optional => 1, default => 'v1.5' },
        saltlen => 'Str', { optional => 1 },
    ],
);
sub verify ($self, $arg) {

    my @arg = ($arg->signature, $arg->message, $arg->digest, $arg->padding);
    if ($arg->padding eq 'pss' && $arg->saltlen) {
        push @arg, $arg->saltlen;
    }
    return $self->_token->verify_message(@arg);
}

signature_for decrypt => (
    method => 1,
    named => [
        message => 'Str',
        padding => 'Str', { optional => 1, default => 'v1.5' },
    ],
);
sub decrypt ($self, $arg) {

    return unless ($self->_secret->is_complete);

    return $self->_token->decrypt( $arg->message, $arg->padding );

}

# required for the "usable" check of the current tokenmanager API
sub login {

    my $self = shift;

    return $self->_secret->is_complete;

}

sub online {

    my $self = shift;

    return 0 unless ($self->_secret->is_complete);

    # build vault if not already loaded
    $self->is_available || $self->_key;

    return 1;
}

sub get_key_info {

    my $self = shift;
    return {
        'is_online' => ($self->online ? 1 : 0),
        'token_id' => $self->certificate->get_cert_identifier,
        'key_name' => $self->key_name,
        'key_cert' => $self->certificate,
        'key_engine' => 'none',
        'key_store' => $self->key_store,
        'key_secret' => ($self->get_passwd() ? 1 : 0),
    }

}

sub get_passwd {
    ##! 16: 'start'
    my $self = shift;

    return unless ($self->_secret->is_complete);

    OpenXPKI::Exception->throw(
        message => 'Secret group is not exportable',
    ) unless ($self->_secret->is_exportable || caller[0] eq ref $self);

    return $self->_secret->get_secret();
}


1;

__PACKAGE__->meta->make_immutable;

__END__;

package OpenXPKI::Server::API2::Plugin::Crypto::scep_message_handler;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::scep_message_handler

=cut

use strict;
use English;
use MIME::Base64;
# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Crypt::PKCS7::SCEP;
use OpenXPKI::Crypt::X509;

=head1 COMMANDS

=head2 scep_unwrap_message

B<Parameters>

=over

=item * C<message> I<Str>

The base64 encoded SCEP message

=back

=cut

command "scep_unwrap_message" => {
    message => { isa => 'Str', required => 1, },
    noverify =>  { isa => 'Bool', default => 0 ,},
} => sub {

    my ($self, $params) = @_;

    ##! 64: 'unpack message'
    ##! 128: $params->message
    my $req = OpenXPKI::Crypt::PKCS7::SCEP->new($params->message);

    ##! 32: 'message unwrapped'
    my $res = {
        #alias => $token_alias,
        transaction_id => $req->transaction_id(),
        sender_nonce => $req->request_nonce(),
        message_type => $req->message_type(),
        digest_alg => $req->digest_alg(),
        enc_alg => $req->enc_alg(),
        key_alg => $req->key_alg(),
    };

    # issuer / serial hash
    my $rcpt = $req->recipient();
    ##! 64: $rcpt
    my $db_rcpt = $self->api->search_cert(
        issuer_dn => $rcpt->{issuer}->get_subject(),
        cert_serial => $rcpt->{serial},
        pki_realm => '_any',
        return_columns => ['identifier','status','data']
    );

    if (!@$db_rcpt) {
        $res->{error} = 'No certificate found to decrypt the message';
        ##! 64: $res
        return $res;
    }

    if ($db_rcpt->[0]->{status} ne 'ISSUED') {
        $res->{error} = 'Recipient certificate is revoked';
        ##! 64: $res
        return $res;
    }

    my $token_list = $self->api->list_active_aliases( type => 'scep' );
    my $token_alias;
    foreach my $token (@$token_list) {
        next unless ($token->{identifier} eq $db_rcpt->[0]->{identifier});
        $req->ratoken( OpenXPKI::Crypt::X509->new($db_rcpt->[0]->{data}) );
        $token_alias = $token->{alias};
    }

    if (!$token_alias) {
        $res->{error} = 'Used recipient is not a valid ratoken';
        ##! 64: $res
        return $res;
    }

    $res->{alias} = $token_alias;

    ##! 16: $token_alias
    my $token = CTX('crypto_layer')->get_token({ TYPE => 'scep', NAME => $token_alias });
    if (my $key_object = $token->get_key_object()) {
        ##! 32: 'Using internal rsa object'
        $req->ratoken_key( $key_object );
    } else {
        $req->ratoken_key( $token );
    }

    if (!$params->noverify) {
        ##! 64: 'run pkcs7_verify'
        ##! 128: $req->message()->pem
        # load the PEM encoded payload of the outer message
        eval{
            CTX('api2')->get_default_token()->command({
                COMMAND => 'pkcs7_verify',
                PKCS7 => $req->message()->pem,
                NO_CHAIN => 1,
            });
        };
        if ($EVAL_ERROR) {
            $res->{error} = 'Invalid signature on PKCS7 envelope';
            CTX('log')->application()->warn($res->{error});
            ##! 64: $res
            return $res;
        }
    }

    $res->{signer} = $req->signer()->pem;

    if ($res->{message_type} eq 'PKCSReq') {
        $res->{pkcs10} = $req->pkcs10()->pem;
    }

    if ($res->{message_type} =~ m{\AGet(Cert|CRL)\z}) {
        $res->{issuer_serial} = $req->issuer_serial();
    }

    ##! 64: $res
    return $res;

};

command "scep_generate_cert_response" => {
    identifier  => { isa => 'Str' },
    alias       => { isa => 'Str', required => 1, },
    signer      => { isa => 'PEMCert', required => 1, },
    transaction_id => { isa => 'Str', required => 1, },
    request_nonce  => { isa => 'Str', },
    reply_nonce    => { isa => 'Str' },
    digest_alg  => { isa => 'Str', default => 'sha256' },
    enc_alg     => { isa => 'Str', default => 'aes-256-cbc' },
    key_alg     => { isa => 'Str', default => 'rsaEncryption' },
    chain       => { isa => 'Str', default => 'chain' , matching => qr{ \A ( none | chain | fullchain ) \Z }x, },

} => sub {

    my ($self, $params) = @_;
    ##! 32: 'Generate SCEP cert response for ' . $params->transaction_id . ' with cert ' . $params->identifier
    return $self->__generate_response($params, 'success');

};

command "scep_generate_failure_response" => {
    failinfo  => { isa => 'Str' },
    alias       => { isa => 'Str', default => sub { return CTX('api2')->get_token_alias_by_type( type => 'scep' ) } },
    transaction_id => { isa => 'Str', required => 1, },
    request_nonce  => { isa => 'Str', },
    reply_nonce    => { isa => 'Str' },
    digest_alg  => { isa => 'Str', default => 'sha256' },
    enc_alg     => { isa => 'Str', default => 'aes-256-cbc' },
} => sub {

    my ($self, $params) = @_;
    ##! 32: 'Generate SCEP failure response for ' . $params->transaction_id
    return $self->__generate_response($params, 'failure');

};

command "scep_generate_pending_response" => {
    alias       => { isa => 'Str', required => 1, },
    transaction_id => { isa => 'Str', required => 1, },
    request_nonce  => { isa => 'Str', },
    reply_nonce    => { isa => 'Str' },
    digest_alg  => { isa => 'Str', default => 'sha256' },
    enc_alg     => { isa => 'Str', default => 'aes-256-cbc' },
} => sub {

    my ($self, $params) = @_;
    ##! 32: 'Generate SCEP pending response for ' . $params->transaction_id
    return $self->__generate_response($params, 'pending');

};

sub __generate_response {

    my ($self, $params, $mode) = @_;

    ##! 32: 'Generate SCEP response for ' . $params->transaction_id
    ##! 64: 'Using alias ' . $params->alias
    my $req = OpenXPKI::Crypt::PKCS7::SCEP->new(
        request_nonce => $params->request_nonce || '',
        transaction_id => $params->transaction_id,
        digest_alg => $params->digest_alg,
        enc_alg => $params->enc_alg,
        ($mode eq 'success' ? (signer => OpenXPKI::Crypt::X509->new($params->signer)) : ()),
    );

    $req->reply_nonce($params->reply_nonce) if ($params->reply_nonce);

    my $token = CTX('crypto_layer')->get_token({ TYPE => 'scep', NAME => $params->alias });
    $req->ratoken_key( $token );

    my $racert =  $self->api->get_certificate_for_alias( alias => $params->alias )->{data};
    $req->ratoken( OpenXPKI::Crypt::X509->new($racert) );

    if ($mode eq 'success') {
        if ($params->chain eq 'none') {
            my $cert = $self->api->get_cert( identifier => $params->identifier, format => 'DER' );
            $req->certs( [ $cert ] );
        } else {
            my $chain = $self->api->get_chain( start_with => $params->identifier, format => 'DER' );
            if ($chain->{complete} && $params->chain ne 'fullchain') {
                pop @{$chain->{certificates}};
            }
            $req->certs( $chain->{certificates} );
        }
        $req->key_alg( $params->key_alg );
        return encode_base64($req->create_cert_response());
    }

    if ($mode eq 'pending') {
        return encode_base64($req->create_pending_response());
    }

    return encode_base64($req->create_failure_response( $params->failinfo ));
}

__PACKAGE__->meta->make_immutable;

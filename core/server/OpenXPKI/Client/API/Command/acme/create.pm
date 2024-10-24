package OpenXPKI::Client::API::Command::acme::create;
use OpenXPKI -client_plugin;

command_setup
    parent_namespace_role => 1,
    needs_realm => 1,
;

=head1 NAME

OpenXPKI::Client::API::Command::acme::create

=head1 DESCRIPTION

Register a new ACME account with an external CA and write the
registration information to the datapool.

=cut

use JSON::PP qw(decode_json);
use Crypt::JWT qw(encode_jwt);
use Crypt::PK::ECC;
use Crypt::PK::RSA;
use Digest::SHA qw(sha256);

use MIME::Base64 qw(decode_base64url encode_base64url);

sub hint_keyspec {
    return [ 'secp384r1 (default)', 'secp256r1', 'secp521r1', 'rsa2048', 'rsa3072', 'rsa4096' ];
}

command "create" => {
    directory => { isa => 'Str', label => 'Directory Url', required => 1 },
    contact => { isa => 'Str', label => 'Contact (email address)', required => 1 },
    label => { isa => 'Str', label => 'Account Label', required => 1 },
    keyspec => { isa => 'Str', label => 'RSA bits (rsaXXXX) or curve name', default => 'secp384r1', hint => 'hint_keyspec' },
    eab_kid => { isa => 'Str', label => 'Ext. Account ID' },
    eab_mac => { isa => 'Str', label => 'Ext. Account MAC Key' },

} => sub ($self, $param) {

    my $label = $param->label || encode_base64url(sha256($param->directory));

    my $res = $self->run_command('get_data_pool_entry', {
        namespace => 'nice.acme.account',
        key => $label,
    });

    die "ACME account for this label already exists\n" if $res->result;

    $self->LOCATION($param->directory);

    die "You must pass both or no external binding parameters\n"
        if ($param->eab_kid xor $param->eab_mac);

    my $eab;
    $eab = {
        kid => $param->eab_kid,
        mac => $param->eab_mac
    } if ($param->has_eab_kid);

    my $account = $self->_registerAccount(
        $param->keyspec,
        $param->contact,
        $eab
    );

    $self->run_command('set_data_pool_entry', {
        namespace => 'nice.acme.account',
        key => $label,
        value => $account,
        serialize => 'simple',
        encrypt => 1,
    });

    return {
        account_id => $account->{kid},
        thumbprint => $account->{thumbprint},
        label => $label
    };
};

# might move this into the core api
sub _registerAccount {

    my $self = shift;
    my $keyspec = shift;
    my $contact = shift;
    # externalAccountBinding - must be a hash with 'kid' and 'mac'
    my $eab = shift;

    my $dir = $self->directory();

    my $pk;
    if ($keyspec =~ m{\Arsa(\d+)\z}) {
        $pk = Crypt::PK::RSA->new();
        $pk->generate_key($1);
    } else {
        $pk = Crypt::PK::ECC->new();
        $pk->generate_key($keyspec);
    }
    my $jwk = $pk->export_key_jwk('public',1);

    my @contact;
    if (ref $contact eq 'ARRAY') {
        @contact = map { 'mailto:'.$_ } @{$contact};
    } elsif ($contact) {
        @contact = ('mailto:'.$contact);
    }

    my $payload = {
        contact => \@contact,
        termsOfServiceAgreed => JSON::PP::true,
    };

    my $account_url = $dir->{newAccount};
    if ($eab) {
        my $eab_payload = encode_jwt(
            # the new key we want to register
            payload => $jwk,
            # the hmac provided by the third party
            key => decode_base64url($eab->{mac}),
            alg => 'HS256',
            extra_headers => {
                url => $account_url,
                # the key id associated with the HMAC (provided by the third party)
                kid => $eab->{kid}
            },
        serialization => 'flattened' );
        $payload->{externalAccountBinding} = decode_json($eab_payload);
    }

    my $alg = 'ES256';
    if ($jwk->{kty} eq 'RSA') {
        $alg = 'RS256';
    } elsif ($jwk->{crv} eq 'P-384') {
        $alg = 'ES384';
    } elsif ($jwk->{crv} eq 'P-521') {
        $alg = 'ES512';
    }

    my $token = encode_jwt( payload => $payload, key => $pk, alg => $alg, extra_headers => {
        nonce => $self->nonce(),
        url => $account_url,
        jwk => $jwk,
    }, serialization => 'flattened' );

    $self->log()->trace(Dumper decode_json($token)) if ($self->log()->is_trace);

    my $ua = $self->agent();
    my $req = HTTP::Request->new(POST => $account_url);
    $req->content_type('application/jose+json');
    $req->content($token);
    my $response = $ua->request($req);
    if ($response->code != 201) {
        die "Something went wrong: " . $response->decoded_content;
    }
    my $location = $response->header('location');
    my $content = decode_json($response->decoded_content);

    return {
        kid => $location,
        jwk => $pk->export_key_jwk('private',1),
        thumbprint => $pk->export_key_jwk_thumbprint(),
        account => $content,
    };

}

__PACKAGE__->meta->make_immutable;

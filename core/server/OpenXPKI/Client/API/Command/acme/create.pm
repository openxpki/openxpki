package OpenXPKI::Client::API::Command::acme::create;

use Moose;
extends 'OpenXPKI::Client::API::Command::acme';

use MooseX::ClassAttribute;

use JSON::PP qw(decode_json);
use Crypt::JWT qw(encode_jwt);
use Crypt::PK::ECC;
use Crypt::PK::RSA;
use Data::Dumper;
use Digest::SHA qw(sha256);
use Feature::Compat::Try;
use LWP::UserAgent;
use MIME::Base64 qw(decode_base64url encode_base64url);

use OpenXPKI::Client::API::Response;
use OpenXPKI::DTO::Field;
use OpenXPKI::DTO::Field::String;
use OpenXPKI::DTO::Field::Realm;

=head1 NAME

OpenXPKI::Client::API::Command::acme::create;

=head1 SYNOPSIS

Register a new acme account with an external ca and write the
registration information to the datapool.

=cut

class_has 'param_spec' => (
    is      => 'ro',
    isa => 'ArrayRef[OpenXPKI::DTO::Field]',
    default => sub {[
        OpenXPKI::DTO::Field::String->new( name => 'directory', label => 'Directory Url', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'contact', label => 'Contact (email address)', required => 1 ),
        OpenXPKI::DTO::Field::String->new( name => 'label', label => 'Account Label' ),
        OpenXPKI::DTO::Field::String->new( name => 'keyspec', label => 'RSA bits (rsaXXXX) or curve name',
            value => 'secp384r1', 'hint' => 'hint_keyspec' ),
        OpenXPKI::DTO::Field::String->new( name => 'eab-kid', label => 'Ext. Account ID' ),
        OpenXPKI::DTO::Field::String->new( name => 'eab-mac', label => 'Ext. Account MAC Key' ),
    ]},
);

sub hint_keyspec {

    my $self = shift;
    my $req = shift;
    my $input = shift;
    return [ 'secp384r1 (default)', 'secp256r1', 'secp521r1', 'rsa2048', 'rsa3072', 'rsa4096' ];

}

sub execute {

    my $self = shift;
    my $req = shift;

    my $client;
    try {


        my $label = $req->param('label') || encode_base64url(sha256($req->param('directory')));

        my $res = $self->api->run_command('get_data_pool_entry', {
            namespace => 'nice.acme.account',
            key => $label,
        });

        return OpenXPKI::Client::API::Response->new( state => 400,
            payload => 'ACME account for this label already exists' ) if ($res);

        $self->LOCATION($req->param('directory'));

        return OpenXPKI::Client::API::Response->new( state => 400,
            payload => 'You must pass both or no external binding parameters' )
                if ($req->param('eab-kid') xor $req->param('eab-mac'));

        my $eab;
        $eab = {
            kid => $req->param('eab-kid'),
            mac => $req->param('eab-mac')
        } if ($req->param('eab-kid'));

        my $account = $self->_registerAccount(
            $req->param('keyspec'),
            $req->param('contact'),
            $eab
        );

        $res = $self->api->run_command('set_data_pool_entry', {
            namespace => 'nice.acme.account',
            key => $label,
            value => $account,
            serialize => 'simple',
            encrypt => 1,
        });

        return OpenXPKI::Client::API::Response->new( payload => {
            account_id => $account->{kid},
            thumbprint => $account->{thumbprint},
            label => $label }
        );
    } catch ($err) {
        return OpenXPKI::Client::API::Response->new( state => 400, payload => $err );
    }

}

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

__PACKAGE__->meta()->make_immutable();

1;


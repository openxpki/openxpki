package OpenXPKI::Server::API2::Plugin::Crypto::generate_key;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::generate_key

=cut

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::API2::Types;



=head1 COMMANDS

=head2 generate_key

Creates a new cryptographic key and returns it encrypted representation in PEM
format.

B<Parameters>

=over

=item * C<password> I<Str> - passwort for key encryption. Required.

=item * C<key_alg> I<Str> - key algorithm, e.g. "RSA", "DSA", "EC" etc. Default: "RSA"

=item * C<enc_alg> I<Str> - encryption algorithm, e.g. "AES256" etc. Default:
crypto backend's default

=item * C<key_length> I<Int> - only RSA/DSA: key length. Default: 2048

=item * C<curve> I<Str> - only EC: curve name. Required.

=item * C<pkeyopt> I<HashRef> - more options to directly pass to OpenSSL.
If specified, these option win over other parameters
(e.g. C<options-E<gt>{rsa_keygen_bits}> wins over C<key_length>)

=item * C<paramset> I<Str> - PEM encoded parameter set whose contents will be
passed to C<openssl genpkey -paramfile ...>

B<Changes compared to API v1:>

The previous parameter C<PARAMS> was removed. The hash keys used in it are now
"first class" parameters:

    # old
    PARAMS => {
        PKEYOPT    =>    { ... },
        KEY_LENGTH => $len,
        ECPARAM    => $pem_ec_param,
        DSAPARAM   => $pem_dsa_param,
        CURVE_NAME => $curve,
    }
    # new
    key_length  => $len,
    pkeyopt     => { ... },
    paramset    => $pem_ec_param, # or $pem_dsa_param
    curve       => $curve,

The previously unused parameter C<ISSUER> was removed.

=back

=cut
command "generate_key" => {
    password    => { isa => 'Str', required => 1, },
    key_alg     => { isa => 'Str', default => 'rsa' },
    key_length  => { isa => 'Int', default => 2048 },
    curve       => { isa => 'Str', },
    enc_alg     => { isa => 'Str', },
    pkeyopt     => { isa => 'HashRef', },
    paramset    => { isa => 'PEM', },
} => sub {
    my ($self, $params) = @_;
    my $key_alg = lc($params->key_alg);
    my $paramset = $params->paramset;

    my $token = CTX('api')->get_default_token();

    # prepare command definition
    my $command = {
         COMMAND => 'create_pkey',
         KEY_ALG => $key_alg,
         $params->has_enc_alg ? (ENC_ALG => $params->enc_alg) : (),
         PASSWD  => $params->password,
    };

    # RSA
    if ($key_alg eq "rsa") {
        $command->{PKEYOPT} = { rsa_keygen_bits => $params->key_length };
    }
    # EC
    elsif ($key_alg eq "ec") {
        # With openssl <=1.0.1 you need to create EC the same way as DSA
        # means params and key in two steps
        # see http://openssl.6102.n7.nabble.com/EC-private-key-generation-problem-td47261.html
        if (not $paramset) {
            OpenXPKI::Exception->throw(
                message => 'Parameter "curve" must be specified for EC key algorithm'
            ) unless $params->has_curve;

            $paramset = $token->command({
                COMMAND => 'create_params',
                TYPE    => 'EC',
                PKEYOPT => { ec_paramgen_curve => $params->curve }
            })
            or OpenXPKI::Exception->throw(message => 'Error generating EC parameter set');
        }
        $command->{PARAM} = $paramset;
        delete $command->{KEY_ALG};
    }
    # DSA
    elsif ($key_alg eq "dsa") {
        if (not $paramset) {
            $paramset = $token->command({
                COMMAND => 'create_params',
                TYPE    => 'DSA',
                PKEYOPT => { dsa_paramgen_bits => $params->key_length }
            })
            or OpenXPKI::Exception->throw(message => 'Error generating DSA parameter set');
        }
        $command->{PARAM} = $paramset;
        delete $command->{KEY_ALG};
    }

    # add additional options
    if ($params->has_pkeyopt) {
        my $opt = $params->pkeyopt;
        $command->{PKEYOPT}->{$_} = $opt->{$_} for keys %$opt;
    }

    CTX('log')->audit('key')->info("generating private key", { key_alg => $key_alg});

    ##! 16: 'command: ' . Dumper $command
    return $token->command($command);
};

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::API2::Plugin::Crypto::generate_key;
use OpenXPKI::Server::API2::EasyPlugin;

=head1 NAME

OpenXPKI::Server::API2::Plugin::Crypto::generate_key

=cut

# Project modules
use OpenXPKI::Debug;
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

=item * C<pkeyopt> I<HashRef>|I<ArrayRef> - more options to directly pass to OpenSSL.
If specified, these option win over other parameters
(e.g. C<options-E<gt>{rsa_keygen_bits}> wins over C<key_length>)
For some combinations openssl needs a defined order of the option params,
if this is required pass a list of hashes. Otherwise a hash with key/values
will also do.

=item * C<paramset> I<Str> - PEM encoded parameter set whose contents will be
passed to C<openssl genpkey -paramfile ...>

B<Changes compared to API v1:>

The previous parameter C<PARAMS> was removed. The hash keys used in it are now
"first class" parameters:

    # old
    PARAMS => {
        PKEYOPT    => { ... },
        KEY_LENGTH => $len,
        ECPARAM    => $pem_ec_param,
        DSAPARAM   => $pem_dsa_param,
        CURVE_NAME => $curve,
    }
    # new
    key_length  => $len,
    pkeyopt     => { p1 => v1, p2 => v2 } or [{ p1 => v1 }, { p2 => v2 }],
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
    pkeyopt     => { isa => 'HashRef|ArrayRef', },
    paramset    => { isa => 'PEM', },
} => sub {
    my ($self, $params) = @_;
    my $key_alg = lc($params->key_alg);
    my $paramset = $params->paramset;

    my $token = $self->api->get_default_token();

    # prepare command definition
    my $command = {
         COMMAND => 'create_pkey',
         KEY_ALG => $key_alg,
         $params->has_enc_alg ? (ENC_ALG => $params->enc_alg) : (),
         PASSWD  => $params->password,
    };

    # RSA
    if ($key_alg eq "rsa") {
        $command->{PKEYOPT} = [{ rsa_keygen_bits => $params->key_length }];
    }
    # EC
    elsif ($key_alg eq "ec") {
        # explicit parameter set is given
        if ($paramset) {
            $command->{PARAM} = $paramset;
            delete $command->{KEY_ALG};
        # curve name is given, also forces named_curve to be set
        } elsif ($params->curve) {
            $command->{PKEYOPT} = [{ ec_paramgen_curve => $params->curve }, { ec_param_enc => "named_curve" }];
        } elsif (!$params->has_pkeyopt) {
            OpenXPKI::Exception->throw(message => 'Either curve, paramset or pkeyopts must be given for EC');
        }
    }
    # DSA
    elsif ($key_alg eq "dsa") {
        if (not $paramset) {
            $paramset = $token->command({
                COMMAND => 'create_params',
                TYPE    => 'DSA',
                PKEYOPT => [{ dsa_paramgen_bits => $params->key_length }]
            })
            or OpenXPKI::Exception->throw(message => 'Error generating DSA parameter set');
        }
        $command->{PARAM} = $paramset;
        delete $command->{KEY_ALG};
    }

    # add additional options
    if ($params->has_pkeyopt) {
        my $opt = $params->pkeyopt;
        if (ref $opt eq 'ARRAY') {
            push @{$command->{PKEYOPT}}, @{$opt};
        } elsif (ref $opt eq 'HASH') {
            push @{$command->{PKEYOPT}}, $opt ;
        } else {
             OpenXPKI::Exception->throw(message => 'Unsupported format for pkeyopt');
        }
    }

    CTX('log')->audit('key')->info("generating private key", { key_alg => $key_alg });

    ##! 16: $command
    return $token->command($command);
};

__PACKAGE__->meta->make_immutable;

package OpenXPKI::Server::NICE::Role::KeyGenerationLocal;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;

use Moose::Role;

=head1 NAME

OpenXPKI::Server::NICE::Role::KeyGenerationLocal

=head2 generateKey

Calls the local API method generate_key, input parameters are "drop in"
compatible to the Tools::GenerateKey activity.

=head3 Input Parameters

Input parameters are positional arguments

=over

=item key algorithm

Key algorithm, passed as is to the I<generate_key> API method

=item key parameters

Hash holding additional key parameters, supported keys are
I<curve_name> and I<key_length>.

=item key transport parameters

Hash holding the parameters for the transport encryption of the key.
Setting a I<password> is mandatory, I<algorithm> defaults to aes256.

=back

=head3 Return Value

The return value is a hash with following paramters.

=over

=item pkey

The PEM encoded private key, including header/footer lines

=item pubkey

The base64 encoded public key (no line breaks or headers)

=item key_id

The key identifier, sha1 hash (uppercase hex) of pubkey, same format
as subject_key_id of PKCS10 and x509 classes.

=back

=cut

sub generateKey {

    my $self = shift;

    my $mode = shift; # not used
    my $key_alg = shift;
    my $key_params = shift;
    my $key_transport = shift;
    my $extra = shift || {};

    my $params = {
        key_alg => $key_alg,
        password => $key_transport->{password},
        enc_alg => $key_transport->{algorithm},
    };

    # password check
    if (not $params->{password}) {
        $self->last_error('I18N_OPENXPKI_UI_NICE_GENERATE_KEY_NO_PASSWORD');
        return;
    }

    foreach my $key (keys %{$key_params}) {
        my $value = $key_params->{$key};
        if ( defined $value && $value ne '' ) {
            if ($key =~ /curve_name/i) {
                $params->{curve} = $value;
            } elsif ($key =~ /key_length/i) {
                $params->{key_length} = $value;
            }
        }
    }

    # command definition
    my $res;
    CTX('log')->audit('key')->info("generating private key via NICE");

    eval {
        my $pkcs8 = CTX('api2')->generate_key(%$params);

        my $pubkey = CTX('api2')->get_default_token()->command({
            COMMAND => "get_pubkey",
            DATA => $pkcs8,
            PASSWD => $params->{password},
        });

        my $pub = OpenXPKI::Crypt::PubKey->new($pubkey);

        $res = {
            pkey => $pkcs8,
            pubkey => encode_base64($pub->data, ''),
            key_id => $pub->get_subject_key_id,
        };
    };
    if ($EVAL_ERROR) {
        CTX('log')->application()->error('Error generating private key: ' . $EVAL_ERROR);
    }
    return $res;

}

1;
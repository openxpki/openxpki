package OpenXPKI::Server::Workflow::Activity::Tools::GenerateKey;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Workflow::Exception qw( configuration_error );


sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params = {
        key_alg  => $self->param('key_alg') || 'rsa',
        enc_alg  => $self->param('enc_alg') || 'aes256',
        password => $self->param('password'),
    };

    if (!$params->{key_alg}) {
        configuration_error('No key algorithm set for generate key');
    }

    # password check
    if (not $params->{password}) {
        configuration_error('No password set for key encryption');
    }

    my $parameters = $self->param('key_gen_params');

    if (defined $parameters && not $parameters) {
        configuration_error('Parameter set is empty for generate key');
    } elsif (ref $parameters eq 'HASH') {

        # TODO - we need to find a suitable way to map and validate parameters
        # for the moment we just support key_length and curve_name and map those
        # to the API method
        foreach my $key (keys %{$parameters}) {
            my $value = $parameters->{$key};
            if ( defined $value && $value ne '' ) {
                if ($key =~ /curve_name/i) {
                    $params->{curve} = $value;
                } elsif ($key =~ /key_length/i) {
                    $params->{key_length} = $value;
                } else {
                    $self->log->warn('Unknown key parameter ' . $key);
                }
            }
        }
    }

    # command definition
    my $pkcs8 = CTX('api2')->generate_key(%$params);

    delete $params->{password};
    CTX('log')->audit('key')->info("generating private key", {
        %{$params}
    });

    my $target_key = $self->param('target_key') || 'private_key';

    $context->param($target_key => $pkcs8);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::GenerateKey

=head1 Description

Creates a new (encrypted) private key with the parameters given. The only
mandatory parameter is the password, the others default to a rsa 2048 bit
key encrypted with aes256.

For details on the parameters please see the documentation of the
generate_key API method.

=head1 Configuration

=head2 Activity Parameters

The key specification parameters are not validated and handed over to the
generate_key method of the crypto token.

=over

=item key_alg

Mapped unmodified to key_alg of the api method, set to 'rsa' of not set.

=item enc_alg

Mapped unmodified to key_alg of the api method, set to 'aes256' of not set.

=item password

Password to encrypt the key with, mandatory.

=item key_gen_params

If parameter is given, it must be a hash. The values given in the key
I<curve_name> and I<key_length> are mapped to the api method as is. Other
keys are silently ignored, no defaults are applied (default key lenght for
RSA/DSA is set in the API method).

=item target_key

The context value to write the encrypted key to. Default is private_key.

=back

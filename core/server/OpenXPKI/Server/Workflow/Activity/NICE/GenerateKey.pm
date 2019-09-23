package OpenXPKI::Server::Workflow::Activity::NICE::GenerateKey;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use Data::Dumper;
use OpenXPKI::Server::NICE::Factory;

sub execute {

    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params = $self->param();
    delete $params->{'target_key'} if (defined $params->{'target_key'});

    my $key_alg = $params->{'key_alg'};
    my $key_gen_params = $params->{'key_gen_params'};
    my $password = $params->{'password'};
    my $transport = {
        password => $params->{'password'},
        algorithm => $params->{'enc_alg'},
    };
    delete $params->{'key_alg'};
    delete $params->{'password'};
    delete $params->{'enc_alg'};
    delete $params->{'key_gen_params'};

    CTX('log')->audit('key')->info("generating private key via NICE");

    ##! 32: 'NICE generatekey parameters ' . Dumper $params
    my $nice_backend = OpenXPKI::Server::NICE::Factory->getHandler( $self );

    my $private_key = $nice_backend->generateKey( '', $key_alg, $key_gen_params, $transport, $params );

    ##! 32: 'NICE key result ' . Dumper $private_key
    my $target_key = $self->param('target_key') || 'private_key';
    $context->param($target_key => $private_key);

    if (!$private_key) {
        my $error = $nice_backend->get_last_error() || 'I18N_OPENXPKI_UI_UNABLE_TO_GENERATE_PRIVATE_KEY';
        CTX('log')->application()->error($error);
        $context->param( 'error_code' =>  $error );
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::NICE::GenerateKey

=head1 Description

Parameters which are common for all backends are given below, any additional
parameter set in the activity is handed over as additional parameter hash
to the backend class.

The result of the call is written to target key, depending on the
implementation this can be the key itself or any other data structure.

If the backend does not return a key, the error message is written to
I<error_code> and the target_key is empty.

=head1 Configuration

=head2 Activity Parameters

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

The context value to write the result key to. Default is private_key.


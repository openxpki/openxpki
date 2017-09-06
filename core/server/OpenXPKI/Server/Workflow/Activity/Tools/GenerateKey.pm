
# This is the NEW Activity which is used by the V2 CSR Workflows
# After decomissioning of the old CSR Workflows, the CSR::GenerateKey
# Activity should be deleted.
# This class does NOT validate the key parameters as this should be done
# in the workflow and uses the new universal create_pkey command

package OpenXPKI::Server::Workflow::Activity::Tools::GenerateKey;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $key_alg = $self->param('key_alg');
    ##! 16: 'key_type: ' . $key_type

    if (! defined $key_alg) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_MISSING_PARAMETERS',
        );
    }

    my $enc_alg = $self->param('enc_alg');

    my $password = $self->param('password');
    # password check
    if (! defined $password || $password eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_MISSING_OR_EMPTY_PASSWORD',
        );
    }

    my $parameters = $self->param('key_gen_params');

    if (! defined $parameters) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_MISSING_PARAMETERS',
        );
    }

    # TODO - we need to find a suitable way to validate parameters against the
    # implementation without hardcoding it in the perl code.
    # For now, we just expect that the workflow has only valid items

    # Run thru the params and uppercase the key name and remove empty sets
    my $param;
    foreach my $key (keys %{$parameters}) {
        my $value = $parameters->{$key};
        if ( defined $value && $value ne '' ) {
            $param->{uc($key)} = $value;
        }
    }

    # command definition
    my $pkcs8 = CTX('api')->generate_key({
         KEY_ALG    => $key_alg,
         ENC_ALG    => $enc_alg,
         PASSWD     => $password,
         PARAMS     => $param,
    });


    CTX('log')->audit('key')->info("generating private key", {
        'key_alg' => $key_alg,
        %{$param}
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

Creates a new (encrypted) private key with the given parameters key_type and
password. key_type is a symbolic name for a given key configuration, the
details of which are defined in key_gen_params. The encrypted private key is
written to the context parameter private_key.

=head1 Configuration

=head2 Activity Parameters

The key specification parameters are not validated and handed over to the
generate_key method of the crypto token.

=over

=item key_alg

=item enc_alg

=item key_gen_params

=item password

=item target_key

The context value to write the encrypted key to. Default is private_key.

=back

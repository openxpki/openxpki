# OpenXPKI::Server::Workflow::Activity::SmartCard::CreateEscrowedKey
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::SmartCard::CreateEscrowedKey;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;

use Data::Dumper;

sub execute {
    my $self     = shift;
    my $workflow = shift;
    my $context  = $workflow->context();

    my $default_token = CTX('api')->get_default_token();

    my $dp_namespace = $self->param('dp_namespace');
    my $dp_key   = $self->param('dp_key');

    my $key_alg    = $self->param('key_alg') || 'RSA';
    my $key_size   = $self->param('key_size') || 2048;
    my $enc_alg   = $self->param('enc_size') || 'aes256';

    my $key_param =  { KEY_LENGTH => $key_size };

    # use fixed password because the key will be stored encrypted in the
    # datapool, might move this to a config item / keynanny
    my $passwd = 'OpenXPKI';

    # command definition
    my $private_key = CTX('api')->generate_key({
         KEY_ALG    => $key_alg,
         ENC_ALG    => $enc_alg,
         PASSWD     => $passwd,
         PARAMS     => $key_param,
    });

    # ultimately we want to save the key under the corresponding certificate
    # identifier, but we don't know this yet. we use a temporary handle
    # and will later rename it.
    # Add some random if we have more than one escrow cert to create
    my $temp_handle = $dp_key . '_' . $workflow->id() . '_'. sprintf('%01d',rand()*100000);

    CTX('api')->set_data_pool_entry({
        NAMESPACE => $dp_namespace,
        KEY       => $temp_handle,
        VALUE     => $private_key,
        # autocleanup of keys which are not crafted into certificates
        # later in this process
        EXPIRATION_DATE => time + 24 * 3600,
        FORCE     => 1,
#        ENCRYPT   => 1,
    });

    ##! 16: 'datapool entry saved to ' . $namespace . ':' . $temp_handle
    CTX('log')->application()->info('Created ' . $key_alg . ' private key for ' . $context->param('creator') . ', saved to datapool entry ' . $dp_namespace . '/' . $temp_handle);


    CTX('log')->audit('key')->info("generating private key", {
        'key_alg' => $key_alg,
        %{$key_param}
    });

    my $csr = $default_token->command (
    {
        COMMAND => "create_pkcs10",
        KEY     => $private_key,
        PASSWD  => $passwd,
        SUBJECT => 'dummy subject',
    });

    $context->param('pkcs10' => $csr);

    $context->param('temp_key_handle' => $temp_handle);

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::SmartCard::CreateEscrowedKey

=head1 SYNOPSIS

    class: OpenXPKI::Server::Workflow::Activity::SmartCard::CreateEscrowedKey
    label: I18N_OPENXPKI_UI_WORKFLOW_ACTION_SCPERS_CREATE_ESCROWED_KEY_LABEL
    description: I18N_OPENXPKI_UI_WORKFLOW_ACTION_SCPERS_CREATE_ESCROWED_KEY_DESC
    param:
        dp_namespace: certificate.privatekey
        _map_dp_key: $token_id
        key_alg: RSA
        key_size: 2048
        enc_alg: aes256

=head1 Description

Generates RSA private key, saves private key in datapool using a temporary
key (lifetime: 24h). Creates PKCS#10 request from private key, exports
request to context.

=head1 Configuration

=head2 Activity parameters

In the activity definition, the following parameters must be set.
See the example that follows.

=over 8

=item dp_namespace

Datapool namespace to use.

=item dp_key

Prefix used to build the temporary datapool handle.

=item key_alg

Public key algorithm to use. Default: 'RSA'

=item key_size

Public key size in bits. Default: 2048

=back

=head2 Context parameters

=over

=item pkcs10

Generated PKCS#10 request.

=item temp_key_handle

Temporary datapool key used for storing the private key.

=back

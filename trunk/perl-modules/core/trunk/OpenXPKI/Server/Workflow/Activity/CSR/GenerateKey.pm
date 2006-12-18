# OpenXPKI::Server::Workflow::Activity::CSR:GenerateKey:
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project
# $Revision: 320 $

package OpenXPKI::Server::Workflow::Activity::CSR::GenerateKey;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Activity::CSR::GenerateKey';
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $pki_realm  = CTX('session')->get_pki_realm();
    my $default_token = CTX('pki_realm')->{$pki_realm}->{crypto}->{default};

    my $params_map = {
        'RSA1024' => {
            TYPE       => 'RSA',
            PARAMETERS => {
                ENC_ALG    => 'aes256',
                KEY_LENGTH => 1024,
            },
        },
        'RSA2048' => {
            TYPE       => 'RSA',
            PARAMETERS => {
                ENC_ALG    => 'aes256',
                KEY_LENGTH => 2048,
            },
        },
        'ECDSA_PRIME192V1' => {
            TYPE       => 'EC',
            PARAMETERS => {
                ENC_ALG    => 'aes256',
                CURVE_NAME => 'prime192v1',
            },
        },
        'ECDSA_C2TNB191V1' => {
            TYPE       => 'EC',
            PARAMETERS => {
                ENC_ALG    => 'aes256',
                CURVE_NAME => 'c2tnb191v1',
            },
        },
        'ECDSA_PRIME239V1' => {
            TYPE       => 'EC',
            PARAMETERS => {
                ENC_ALG    => 'aes256',
                CURVE_NAME => 'prime239v1',
            },
        },
    },

    my $key_type = $context->param('_key_type');
    ##! 16: 'key_type: ' . $key_type
    my $password = $context->param('_password');
    
    if (! exists $params_map->{$key_type}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_WRONG_KEYTYPE',
            params => {
                'KEYTYPE' => $key_type,
            },
        );
    }
    my $command = $params_map->{$key_type};

    if (! defined $password || $password eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_MISSING_OR_EMPTY_PASSWORD',
        );
    }
    $command->{PASSWD}  = $password;
    $command->{COMMAND} = 'create_key';
    ##! 16: 'command: ' . Dumper $command

    my $key = $default_token->command($command);
    ##! 16: 'key: ' . $key

    $context->param('private_key' => $key);

    # pass on the password to the PKCS#10 generation activity
    $context->param('_password'   => $password);
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::CSR::GenerateKey

=head1 Description

Creates a new (encrypted) private key with the given parameters
_key_type and _password. _key_type is a symbolic name for a
given key configuration, the details of which are defined in
$params_map.
The encrypted private key is written to the context parameter
private_key, while the password is passed on in the volatile
param '_password', as it is still needed for the PKCS#10 generation.


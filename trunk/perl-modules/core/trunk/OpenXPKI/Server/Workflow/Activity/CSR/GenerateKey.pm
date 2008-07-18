# OpenXPKI::Server::Workflow::Activity::CSR:GenerateKey:
# Written by Alexander Klink for the OpenXPKI project 2006
# Rewritten by Julia Dubenskaya for the OpenXPKI project 2007
# Copyright (c) 2006-2007 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::CSR::GenerateKey;

use strict;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;

use Data::Dumper;

sub execute
{
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $default_token = CTX('pki_realm_by_cfg')->
                           {$self->config_id()}->
                           {$self->{PKI_REALM}}->{crypto}->{default};

    my $key_type = $context->param('_key_type');
    ##! 16: 'key_type: ' . $key_type

    my $password = $context->param('_password');
    # password check
    if (! defined $password || $password eq '') {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_MISSING_OR_EMPTY_PASSWORD',
        );
    }

    my $supported_algs = $default_token->command({COMMAND       => "list_algorithms",
                                                  FORMAT        => "all_data"});
    
    # keytype check
    if (! exists $supported_algs->{$key_type}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_WRONG_KEYTYPE',
            params => {
                'KEYTYPE' => $key_type,
            },
        );
    }

    my $serializer = OpenXPKI::Serialization::Simple->new({SEPARATOR => "-"});
    my $context_parameters = $context->param('_key_gen_params');
    if (! defined $context_parameters) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_MISSING_PARAMETERS',
        );
    }
    my $parameters = $serializer->deserialize($context_parameters);

    # parameters check
    my ($param, $value, $param_values) = ("","","undef");
    while (($param, $value) = each(%{$parameters})) {
        if (! exists $supported_algs->{$key_type}->{$param}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_UNSUPPORTED_PARAMNAME',
                params => {
                    'KEYTYPE'   => $key_type, 
                    'PARAMNAME' => $param,
                }
            );
        } # if param name is not supported

        $param_values = $default_token->command({COMMAND       => "list_algorithms",
                                                 FORMAT        => "param_values",
                                                 ALG           => $key_type,
                                                 PARAM         => $param});
                                      
        if (! exists $param_values->{$value}) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_CSR_GENERATEKEY_UNSUPPORTED_PARAMVALUE',
                params => {
                    'KEYTYPE'    => $key_type, 
                    'PARAMNAME'  => $param,
                    'PARAMVALUE' => $value,
                }
            );
        } #  if param value is not supported
    } # while each(%{$parameters})

    # command definition
    my $command = {
         COMMAND    => 'create_key',
         TYPE       => $key_type,
         PASSWD     => $password,
         PARAMETERS => $parameters,
    };
    ##! 16: 'command: ' . Dumper $command

    my $key = $default_token->command($command);
    ##! 16: 'key: ' . $key

    CTX('log')->log(
	MESSAGE => 'Created ' . $key_type . ' private key for ' . $context->param('creator'),
	PRIORITY => 'info',
	FACILITY => 'audit',
	);

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


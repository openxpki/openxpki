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
    
    my $default_token = CTX('pki_realm_by_cfg')->{$self->config_id()}->{$self->{PKI_REALM}}->{crypto}->{default};
    
    my $namespace = $self->param('ds_namespace');

    my $ds_key_param = $self->param('ds_key_param') || 'token_id';
    my $ds_key       = $context->param($ds_key_param);

    
    my $keyalg    = $context->param('keyalg') || 'RSA';
    my $keysize   = $context->param('keysize') || 1024;
    
    my $supported_algs = $default_token->command(
	{
	    'COMMAND'     => "list_algorithms",
	    'FORMAT'      => "all_data",
        }); 
    
    # keytype check
    if (! exists $supported_algs->{$keyalg}) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_SMARTCARD_CREATEESCROWEDKEY_WRONG_KEYTYPE',
            params => {
                'KEYTYPE' => $keyalg,
            },
        );
    }


    # use fixed password because the key will be stored encrypted in the
    # datapool
    my $passwd = 'OpenXPKI';
    my $command = {
	COMMAND    => 'create_key',
	TYPE       => $keyalg,
	PASSWD     => $passwd,
	PARAMETERS => {
	    KEY_LENGTH => $keysize,
	},
    };
    ##! 16: 'command: ' . Dumper $command

    my $private_key = $default_token->command($command);

    # ultimately we want to save the key under the corresponding certificate
    # identifier, but we don't know this yet. we use a temporary handle
    # and will later rename it.
    my $temp_handle = $ds_key . '_' . $workflow->id();
 
    CTX('api')->set_data_pool_entry(
	{
	    NAMESPACE => $namespace,
	    KEY       => $temp_handle,
	    VALUE     => $private_key,
	    # autocleanup of keys which are not crafted into certificates
	    # later in this process
	    EXPIRATION_DATE => time + 24 * 3600,
	    FORCE     => 1,
	    ENCRYPT   => 1,
	});

    CTX('dbi_backend')->commit();
    
    ##! 16: 'datapool entry saved to ' . $namespace . ':' . $temp_handle
    CTX('log')->log(
	MESSAGE => 'Created ' . $keyalg . ' private key for ' . $context->param('creator') . ', saved to datapool entry ' . $namespace . '/' . $temp_handle,
	PRIORITY => 'info',
	FACILITY => 'audit',
	);
    
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

=head1 Description

Generates RSA private key, saves private key in datapool using a temporary
key (lifetime: 24h). Creates PKCS#10 request from private key, exports
request to context.

=head1 Configuration

=head2 Activity parameters

In the activity definition, the following parameters must be set.
See the example that follows.

=over 8

=item ds_namespace

Datapool namespace to use.

=item ds_key_param

The name of the context parameter that contains the key basename for this
datastore entry. Default: 'token_id'

=back

=head2 Context parameters

=over 8 

=item keyalg (input)

Public key algorithm to use. Default: 'RSA'

=item keysize (input)

Public key size in bits. Default: 2048

=item pkcs10 (output)

Generated PKCS#10 request.

=item temp_datapool_key

Temporary datapool key used for storing the private key.

=back

# OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry
# Written by Alexander Klink for the OpenXPKI project 2006
# Copyright (c) 2006 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Net::LDAP;
use Template;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $params     = { PKI_REALM => CTX('api')->get_pki_realm(), };

    foreach my $key (qw( namespace key_param value_param encrypt force )) {
        my $pkey = 'ds_' . $key;
        my $val  = $self->param($pkey);
        if ( not defined $val ) {
            OpenXPKI::Exception->throw( message =>
                    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
                  . 'MISSPARAM_'
                  . uc($key) );
        }
    }
    foreach my $key (qw( namespace encrypt force )) {
        $params->{ uc($key) } = $self->param( 'ds_' . $key );
    }

    my $keyparam = $self->param('ds_key_param');
    if ( not defined $keyparam ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
              . 'MISSPARAM_KEY_PARAM' );
    }

    $params->{KEY} = $context->param($keyparam);

    my $valparam = $self->param('ds_value_param');
    if ( not defined $valparam ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
              . 'MISSPARAM_VALUE_PARAM' );
    }

    if (    $params->{ENCRYPT}
        and not $valparam =~ m/^_/ )
    {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
              . 'VALKEY_NONVOL' );
    }

    $params->{VALUE} = $context->param($valparam);

    CTX('api')->set_data_pool_entry($params);
    CTX('dbi_backend')->commit();

    # TODO: handle return code from set_data_pool_entry()

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry

=head1 Description

This class sets an entry in the Datapool.

=head1 Configuration

=head2 Parameters

In the activity definition, the following parameters must be set.
See the example that follows.

=over 8

=item ds_namespace

The namespace to use for storing the key-value pair. Generally speaking,
there are no rigid naming conventions. The namespace I<sys>, however,
is reserved for internal server and system related data.

=item ds_key_param

The name of the context parameter that contains the key for this
datastore entry.

=item ds_value_param

The name of the context parameter that contains the value for this 
datastore entry.

B<Note:> If encryption is enabled, the parameter name must be 
preceeded with an underscore.

=item ds_encrypt

A boolean value that specifies whether the value of the entry is to be 
encrypted. [optional - default is I<0>]

=item ds_force 

Causes the set action to overwrite an existing entry.

=back

=head2 Arguments

The workflow action requires two parameters that are passed via the
workflow context. The names are set above with the I<ds_key_param> and
I<ds_value_param> parameters.

=head2 Example

  <action name="set_puk_in_datapool"
    class="OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry"
    ds_namespace="puk_namespace"
    ds_key_param="token_id"
    ds_value_param="_puk"
    ds_encrypt="1"
    ds_force="1" >
    <field name="token_id" label="Serial number of Smartcard"/>
    <field name="_puk" label="Smartcard PUK"/>
  </action>


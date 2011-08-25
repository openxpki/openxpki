# OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry
# Written by Scott Hardin for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry;

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

    foreach my $key (qw( namespace key_param value_param )) {
        my $pkey = 'ds_' . $key;
        my $val  = $self->param($pkey);
        if ( not defined $val ) {
            OpenXPKI::Exception->throw( message =>
                    'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
                  . 'MISSPARAM_'
                  . uc($key) );
        }
    }

    foreach my $key (qw( namespace )) {
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

    #   $params->{VALUE} = $context->param($valkey);

    my $msg = CTX('api')->get_data_pool_entry($params);

    my $retval = $msg->{VALUE};

    my $default_value = $self->param('ds_default_value');

    if ( not defined $retval ) {
        if ( defined $default_value ) {
            if ( $default_value =~ s/^\$// ) {
                $default_value = $context->param($default_value);
            }
            $retval = $default_value;
        }
    }

    ##! 1: 'returned from get_data_pool_entry(): ' . Dumper($msg)
    $context->param($valparam, $retval);

    return;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry

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

=item ds_default_value

The default value to be returned if no record in the datapool is
found. If preceeded with a dollar symbol '$', then the workflow
context variable with the given name will be used.

=back

=head2 Arguments

The workflow action requires two parameters that are passed via the
workflow context. The names are set above with the I<ds_key_param> and
I<ds_value_param> parameters.

=head2 Return Value

The resulting value is returned in the named-parameter list with the
key I<VALUE>.

=head2 Example

  <action name="get_puk_from_datapool"
    class="OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry"
    ds_namespace="puk_namespace"
    ds_key_param="token_id"
    ds_value_param="_puk">
    <field name="token_id" label="Serial number of Smartcard"/>
  </action>


# OpenXPKI::Server::Workflow::Activity::Tools::Datapool::AppendToEntry
# Written by Oliver Welter for the OpenXPKI project 2013
# Copyright (c) 2013 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::AppendToEntry;

use strict;
use warnings;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Crypto::Profile::Certificate;
use OpenXPKI::Crypto::X509;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Server::Workflow::WFObject::WFArray;
use OpenXPKI::Debug;
use MIME::Base64;
use English;

use Data::Dumper;

sub execute {

    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $realm      = CTX('session')->data->pki_realm;

    # Check existance of necessary values
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

    # Resolve key and value
    my $keyparam = $self->param('ds_key_param');
    if ( not defined $keyparam ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
              . 'MISSPARAM_KEY_PARAM' );
    }
    my $keyvalue = $context->param( $keyparam );
    if ( not $keyvalue ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
              . 'KEY_PARAM_EMPTY' );
    }

    my $valparam = $self->param('ds_value_param');
    if ( not defined $valparam ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
              . 'MISSPARAM_VALUE_PARAM' );
    }

    my $params = {
        PKI_REALM => CTX('api')->get_pki_realm(),
        NAMESPACE => $self->param( 'ds_namespace' ),
        KEY       => $keyvalue,
    };

    ##! 16: 'Loading entry with params ' . Dumper $params
    my $dp_entry = CTX('api')->get_data_pool_entry( $params );

    ##! 16: 'Return from API ' . Dumper $dp_entry

    my $value = [];
    if ($dp_entry && $dp_entry->{VALUE}) {

        ##! 8: 'Appending'

        $value = $serializer->deserialize( $dp_entry->{VALUE} );

        ##!16: 'Exisiting value ' . Dumper $value

        if (ref $value ne "ARRAY") {
            if ($params->{FORCE}) {
                $value = [];
            } else {
                OpenXPKI::Exception->throw(
                    message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_EXISTING_VALUE_NOT_AN_ARRAY',
                    params => { REFTYPE => ref $value, VALUE => $value }
                );
            }
        }

        # Force needed to overwrite exisiting entry
        $params->{FORCE} = 1;
        # Take over encryption and expiration
        $params->{ENCRYPT} = $dp_entry->{ENCRYPTED};
        $params->{EXPIRATION_DATE} = $dp_entry->{EXPIRATION_DATE} if ($dp_entry->{EXPIRATION_DATE});

    } else {
        ##! 8: 'Create new'
        $dp_entry = $params;
        $params->{ENCRYPT} = $self->param('ds_encrypt');
    }

    if ( $self->param('ds_expiration_date') ) {
        my $then = OpenXPKI::DateTime::get_validity(
            {
                REFERENCEDATE  => DateTime->now(),
                VALIDITY       =>  $self->param('ds_expiration_date'),
                VALIDITYFORMAT => 'relativedate',
            }
        );
        $params->{EXPIRATION_DATE} = $then->epoch();
    }

    if ($params->{ENCRYPT} and not $valparam =~ m/^_/ ) {
        OpenXPKI::Exception->throw(
            message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_ENCRYPT_PARAM_NONVOL' );
    }

    # Append new value
    push @{$value},  $context->param($valparam);

    # serialize the value
    $params->{VALUE} = $serializer->serialize( $value );



    ##! 16: 'Store with params: ' . Dumper $dp_entry


    CTX('api')->set_data_pool_entry( $params );

    if ($self->param('ds_unset_context_value')) {
        ##! 16: 'clearing context parameter ' . $valparam

        # Workflow does not allow to delete workflow context entries or
        # set them to undef, hence work around this bug by setting the
        # value to an empty string
        $context->param($valparam => '');
    }

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::AppendToEntry

=head1 Description

Shortcut to append an item to a possibly existing datapool entry.
The value is an array, the new value is pushed to the end of the array.
If the entry does not exist or is empty, it is created. If the value exists
and is not an array, the action fails.

=head1 Examples
    <action name="scpers_register_certificate"
        class="OpenXPKI::Server::Workflow::Activity::Tools::Datapool::AppendToEntry"
        ds_namespace="user.certificate"
        ds_key_param="username"
        ds_value_param="cert_identifier"
        ds_encrypt="0"
        ds_unset_context_value="0"
        ds_expiration_date="+10" >
    </action>

=head1 Parameters

The parameters are the same as in SetEntry, with two exceptions:

=head2 ds_force

Do not fail if the current value of the datapool entry is not an array. The
old information is discarded and replaced with the new element.

=head2 ds_encrypt

Only evaluated when creating a new entry. Existing entries keep their
encryption flag.


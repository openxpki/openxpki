package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;
use DateTime;
use Template;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $params     = { PKI_REALM => CTX('api')->get_pki_realm(), };

    # fallback to old parameter format
    my $prefix = '';
    if ($self->param('ds_namespace')) {
        $prefix = 'ds_';

        # get the name of the key and resolve it
        my $dp_key_param = $self->param('ds_key_param');
        if ( not $dp_key_param ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_MISSPARAM_KEY_PARAM'
            );
        }
        $params->{ KEY } = $context->param( $dp_key_param );

        my $dp_value_param = $self->param('ds_value_param');
        if ( not $dp_value_param ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_MISSPARAM_VALUE_PARAM'
            );
        }
        $params->{ VALUE } = $context->param( $dp_value_param );

        CTX('log')->application()->debug('Old parameter format found in set datapool activity');


    } else {
        $params->{ KEY } = $self->param( 'key' );
        $params->{ VALUE } = $self->param( 'value' );
    }

    # map those parameters 1:1 to the API method
    foreach my $key (qw( namespace encrypt force expiration_date )) {
        my $val =  $self->param($prefix.$key);
        if (defined $val) {
            $params->{ uc($key) } = $val;
        }
    }

    # check for mandatory fields
    foreach my $key (qw( namespace key encrypt force )) {
        if ( not defined $params->{ uc($key) } ) {
            OpenXPKI::Exception->throw( message =>
                'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_' .
                'MISSPARAM_' . uc($key)
            );
        }
    }

    if (defined $params->{EXPIRATION_DATE}) {
        my $then = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE  => DateTime->now(),
            VALIDITY       => $params->{EXPIRATION_DATE},
            VALIDITYFORMAT => 'detect',
        });
        $params->{EXPIRATION_DATE} = $then->epoch();
    }

    CTX('api')->set_data_pool_entry($params);

    # we support this feature only in legacy mode
    if ($self->param('ds_unset_context_value')) {
        ##! 16: 'clearing context parameter ' . $valparam
        my $valparam  = $self->param('ds_value_param');
        $context->param( $valparam => undef );
    }

    CTX('log')->application()->info('Set datapool entry for key '.$params->{KEY}.' in namespace '.$params->{NAMESPACE});


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

In the activity definition, the following parameters must be set. The syntax
using the I<ds_> prefix is deprecated, use the I<_map> syntax to load key and
value from the context. It is not allowed to mix prefixed and non-prefixed
parameters!

=over 8

=item namespace / ds_namespace

The namespace to use for storing the key-value pair. Generally speaking,
there are no rigid naming conventions. The namespace I<sys>, however,
is reserved for internal server and system related data.

=item encrypt / ds_encrypt

A boolean value that specifies whether the value of the entry is to be
encrypted. [optional - default is I<0>]

=item force / ds_force

Causes the set action to overwrite an existing entry.

=item expiration_date / ds_expiration_date

Sets expiration date of the datapool entry to the specified value.
The value should be a time specification recognized by OpenXPKI::DateTime
autodetection. (such as '+000001', which means one day), a terse data or
epoch. See OpenXPKI::DateTime::get_validity for details.

=item key

The value used as datapool key, use I<_map> syntax to use values from context!

=item value

The actual value written to the datapool, use I<_map> syntax to use values
from context!

=item ds_key_param, deprecated

The name of the context parameter that contains the key for this
datastore entry. Deprecated, use key with _map syntax instead.

=item ds_value_param, deprecated

The name of the context parameter that contains the value for this
datastore entry. Deprecated, use value with _map syntax instead.

=item ds_unset_context_value, deprecated

If this parameter is set to 1 the activity clears the workflow context
value specified via ds_value_param after storing the value in the datapool.
This options is deprecated and will be removed in the future. Use volatile
parameters or clear them afterwards.

=back

=head2 Arguments

The workflow action requires two parameters that are passed via the
workflow context. The names are set above with the I<ds_key_param> and
I<ds_value_param> parameters.

=head2 Example

    set_puk_in_datapool:
        class: OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry
        param:
            namespace: puk_namespace
            _map_key: $token_id
            _map_value: $_puk
            encrypt: 1
            force: 1
            expiration_date: "+10"

=head2 Example (Legacy format - same result as above)

    set_puk_in_datapool:
        class: OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry
        param:
            ds_namespace: puk_namespace
            ds_key_param: token_id
            ds_value_param: _puk
            ds_encrypt: 1
            ds_force: 1
            ds_unset_context_value: 0
            ds_expiration_date: "+10"


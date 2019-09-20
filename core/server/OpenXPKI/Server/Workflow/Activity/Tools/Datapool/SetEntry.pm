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
use Workflow::Exception qw( workflow_error configuration_error );

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params = {};
    # map those parameters 1:1 to the API method
    foreach my $key (qw( key value namespace encrypt force expiration_date )) {
        my $val =  $self->param($key);
        if (defined $val) {
            $params->{ $key } = $val;
        }
    }

    # check for mandatory fields
    foreach my $key (qw( namespace key encrypt force )) {
        if ( not defined $params->{ $key } || $params->{ $key } eq '' ) {
            configuration_error('Mandatory parameter missing or empty: '.$key);
        }
    }

    if (defined $params->{expiration_date}) {
        my $then = OpenXPKI::DateTime::get_validity({
            REFERENCEDATE  => DateTime->now(),
            VALIDITY       => $params->{expiration_date},
            VALIDITYFORMAT => 'detect',
        });
        if ($then->epoch() < time) {
            workflow_error('Expiration date is in the past');
        }
        $params->{expiration_date} = $then->epoch();
    }

    if ($self->param('pki_realm')) {
        if ($self->param('pki_realm') eq '_global') {
            $params->{pki_realm} = '_global';
        } elsif($self->param('pki_realm') ne CTX('session')->data->pki_realm) {
            workflow_error( 'Access to foreign realm is not allowed' );
        }
    }

    # Datapool handles only scalar values so we need to serialize
    # any non scalar items
    if ($self->param('serialize') && ref $params->{ value }) {
        $params->{ value } = OpenXPKI::Serialization::Simple->new()->serialize( $params->{ value } );
    }

    ##! 32: 'Params ' . Dumper $params
    CTX('api2')->set_data_pool_entry(%$params);

    CTX('log')->application()->info('Set datapool entry for key '.$params->{key}.' in namespace '.$params->{namespace});

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

=item namespace

The namespace to use for storing the key-value pair. Generally speaking,
there are no rigid naming conventions. The namespace I<sys>, however,
is reserved for internal server and system related data.

=item encrypt

A boolean value that specifies whether the value of the entry is to be
encrypted. [optional - default is I<0>]

=item force

Causes the set action to overwrite an existing entry.

=item expiration_date

Sets expiration date of the datapool entry to the specified value.
The value should be a time specification recognized by OpenXPKI::DateTime
autodetection. (such as '+000001', which means one day), a terse data or
epoch. See OpenXPKI::DateTime::get_validity for details.

=item key

The value used as datapool key, use I<_map> syntax to use values from context!

=item value

The actual value written to the datapool, use I<_map> syntax to use values
from context!

=item pki_realm

The realm of the datapool item to load, default is the current realm.

B<Note:> For security reasons it is not allowed to load items from other
realms except from special I<system> realms. The only system realm
defined for now is I<_global> which is available from all other realms.

=item serialize

Boolean, if set the value is serialized so it is possible to store
non-scalar items in the datapool.

=back

=head2 Arguments

The workflow action requires two parameters that are passed via the
workflow context. The names are set above with the I<key> and
I<value> parameters.

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

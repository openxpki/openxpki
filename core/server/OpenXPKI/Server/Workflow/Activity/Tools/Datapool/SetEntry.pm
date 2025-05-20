package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry;
use OpenXPKI;

use parent qw( OpenXPKI::Server::Workflow::Activity );

# CPAN modules
use DateTime;
use Template;
use Workflow::Exception qw( workflow_error configuration_error );

# Project modules
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;


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
    foreach my $key (qw( namespace key encrypt force value )) {
        ##! 32: 'Check for mandatory field ' . $key
        ##! 64: $params->{ $key }
        if ( not defined $params->{ $key }  or $params->{ $key } eq '' ) {
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

    # implicit delete is deprecated to we call delete here
    if ($params->{ value } eq '') {
        ##! 32: 'Emtpy value - reroute to delete command'
        CTX('api2')->delete_data_pool_entry(
            namespace => $params->{namespace},
            key => $params->{key}
        );
        CTX('log')->application()->info('Delete (implicit) datapool entry for key '.$params->{key}.' in namespace '.$params->{namespace});
        return 1;

    }

    try {
        if (ref $params->{value} and $self->param('serialize')) {
            $params->{serialize} = 'simple';
        }
        ##! 32: 'Params ' . Dumper $params
        CTX('api2')->set_data_pool_entry(%$params);
    }
    catch ($err) {
        workflow_error($err);
    }

    CTX('log')->application->info('Set datapool entry: key = '.$params->{key}.', namespace = '.$params->{namespace});

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry

=head1 Description

Sets an entry in the Datapool.

=head1 Configuration

=head2 Mandatory Parameters

namespace key encrypt force value

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

=item key

The value used as datapool key, use I<_map> syntax to use values from context!

=item value

The actual value written to the datapool, use I<_map> syntax to use values
from context! If the value is an empty string, the item is deleted from the
datapool. If the value is not a scalar you must set the I<serialize>
attribute to enable automatic serialization, otherwise the call will fail
with an error.

=back

=head2 Optional Parameters

=over 8

=item pki_realm

The realm of the datapool item to load, default is the current realm.

B<Note:> For security reasons it is not allowed to load items from other
realms except from special I<system> realms. The only system realm
defined for now is I<_global> which is available from all other realms.

=item expiration_date

Sets expiration date of the datapool entry to the specified value.
The value should be a time specification recognized by OpenXPKI::DateTime
autodetection. (such as '+000001', which means one day), a terse data or
epoch. See OpenXPKI::DateTime::get_validity for details.

=item serialize

Boolean, if set the value is serialized so it is possible to store
non-scalar items in the datapool.

=back

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

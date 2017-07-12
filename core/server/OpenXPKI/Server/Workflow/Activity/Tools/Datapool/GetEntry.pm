package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use Workflow::Exception qw(configuration_error workflow_error);

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();
    my $serializer = OpenXPKI::Serialization::Simple->new();
    my $params     = { PKI_REALM => CTX('api')->get_pki_realm(), };

    my $target_key;
    my $default_value;

    # Legacy mode
    if ($self->param('ds_namespace')) {
        ##! 16: 'Doing Legacy mode'
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

        $target_key = $self->param('ds_value_param');
        if ( not $target_key ) {
            OpenXPKI::Exception->throw(
                message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_'
                . 'MISSPARAM_VALUE_PARAM' );
        }

        $default_value = $self->param('ds_default_value');

    } else {

        $params->{NAMESPACE} = $self->param('namespace');
        if (!$params->{NAMESPACE}) {
            configuration_error('Datapool::GetEntry requires the namespace parameter');
        }

        $params->{KEY} = $self->param('key');
        if (!$params->{KEY}) {
            configuration_error('Datapool::GetEntry requires the key parameter');
        }

        $target_key = $self->param('target_key') || '_tmp';

        $default_value = $self->param('default_value');
    }


    ##! 16: ' Fetch from datapool ' . Dumper $params

    my $msg = CTX('api')->get_data_pool_entry($params);

    ##! 32: ' Result from datapool ' . Dumper $msg

    # Prevent export of encrypted data to persisted context items
    if ($msg->{ENCRYPTED} && ($target_key !~ /^_/)) {
         workflow_error( 'persisting encrypted data is not allowed' );
    }

    my $retval = $msg->{VALUE};

    if ( (not defined $retval) && (defined $default_value)) {
        ##! 16: 'No result - using default value'
        $retval = $default_value;
    }

    ##! 1: 'returned from get_data_pool_entry(): ' . $retval
    $context->param({ $target_key => $retval });

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::GetEntry

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

=item key

The value used as datapool key, use I<_map> syntax to use values from context!

=item target_key

The context target key to write the result to, the default is I<_tmp>.

B<Note:> If the retrieved value was encrypted in the datapool, the
target parameter must start with an underscore (=volatile parameter).

=item ds_key_param, deprecated

The name of the context parameter that contains the key for this
datastore entry.

=item ds_value_param, deprecated

The name of the context parameter that contains the value for this
datastore entry.


B<Note:> If the retrieved value was encrypted in the datapool, the
target parameter must start with an underscore (=volatile parameter).

=item ds_default_value

The default value to be returned if no record in the datapool is
found. If preceeded with a dollar symbol '$', then the workflow
context variable with the given name will be used.

=back



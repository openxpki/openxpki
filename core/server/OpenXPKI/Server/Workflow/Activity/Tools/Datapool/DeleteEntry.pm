# OpenXPKI::Server::Workflow::Activity::Tools::Datapool::SetEntry
# Written by Scott Hardin for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::DeleteEntry;

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

    # New format
    if ($self->param('namespace')) {
        $params->{NAMESPACE} = $self->param('namespace');
        $params->{KEY} = $self->param('key');
    } else {

        if (!$self->param('ds_namespace')) {
            OpenXPKI::Exception->throw( message =>
                        'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_MISSPARAM_NAMESPACE');
        };

        $params->{NAMESPACE} = $self->param('ds_namespace');

        if (!$self->param('ds_key_name') && !$self->param('ds_key_param')) {
            OpenXPKI::Exception->throw( message =>
                        'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_MISSPARAM_KEY');
        };

        if ($self->param('ds_key_param')) {
            $params->{KEY} = $context->param( $self->param('ds_key_param') );
        } else {
            $params->{KEY} = $self->param('ds_key_name');
        }

    }

    $params->{VALUE} = undef;


    CTX('log')->application()->info('Remove datapool entry for key '.$params->{KEY}.' in namespace '.$params->{NAMESPACE});


    CTX('api')->set_data_pool_entry($params);
    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::DeleteEntry

=head1 Description

This class deletes an entry from the Datapool, defined by namespace and key.

=head1 Configuration

=head2 Activity Paramaters

=over

=item namespace

=item key

=back

=head2 Activity Parameters (old format, deprecated)

In the activity definition, ds_namespace and one of the ds_key* parameters must be set.
See the example that follows.

=over 8

=item ds_namespace

The namespace to use for storing the key-value pair. Generally speaking,
there are no rigid naming conventions. The namespace I<sys>, however,
is reserved for internal server and system related data.

=item ds_key_param

The name of the context parameter that contains the key for this
datastore entry.

=item ds_key_name

The name of the key for the datastore entry.

=back

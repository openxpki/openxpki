# OpenXPKI::Server::Workflow::Activity::Tools::Datapool::ModifyEntry
# Written by Martin Bartosch for the OpenXPKI project 2010
# Copyright (c) 2010 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Activity::Tools::Datapool::ModifyEntry;

use strict;
use English;
use base qw( OpenXPKI::Server::Workflow::Activity );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::DateTime;
use DateTime;
use Template;

use Data::Dumper;

sub execute {
    ##! 1: 'start'
    my $self       = shift;
    my $workflow   = shift;
    my $context    = $workflow->context();

    my $params     = { 
	PKI_REALM => CTX('api')->get_pki_realm(), 
    };

    foreach my $key (qw( namespace key )) {
        my $pkey = 'ds_' . $key;
        my $val  = $self->param($pkey);
        if ( not defined $val ) {
            OpenXPKI::Exception->throw(
		message =>
		'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_TOOLS_DATAPOOL_MODIFYENTRY_MISSPARAM',
		params => {
		    PARAM => $pkey,
		},
		);
	}
    }

    foreach my $key (qw( namespace key newkey expiration_date )) {
	if (defined $self->param( 'ds_' . $key )) {
	    $params->{ uc($key) } = $self->param( 'ds_' . $key );
	}
    }

    foreach my $key (qw( KEY NEWKEY )) {
	# dereference if necessary
	if ($params->{$key} =~ m{ \A \$ (.*) }xms) {
	    $params->{$key} = $context->param($1);
	}
    }

    
    if (exists $params->{EXPIRATION_DATE}) {
	if (defined $params->{EXPIRATION_DATE} 
	    && ($params->{EXPIRATION_DATE} ne '')) {
	    my $then = OpenXPKI::DateTime::get_validity(
		{
		    REFERENCEDATE  => DateTime->now(),
		    VALIDITY       => $params->{EXPIRATION_DATE},
		    VALIDITYFORMAT => 'relativedate',
		});
	    $params->{EXPIRATION_DATE} = $then->epoch();
	} else {
	    $params->{EXPIRATION_DATE} = undef;
	}
    }

    ##! 16: 'modify_data_pool_entry params: ' . Dumper $params
    CTX('api')->modify_data_pool_entry($params);

    CTX('dbi_backend')->commit();

    return 1;
}

1;
__END__

=head1 Name

OpenXPKI::Server::Workflow::Activity::Tools::Datapool::ModifyEntry

=head1 Description

This class modifies an entry in the Datapool.

=head1 Configuration

=head2 Parameters

In the activity definition, the following parameters must be set.
See the example that follows.

=over 8

=item ds_namespace

The namespace to use.

=item ds_key

Key within the namespace to access. If it starts with a $, the context
value with the specified name is dereferenced.

=item ds_force 

Causes the set action to overwrite an existing entry.

=item ds_expiration_date

Sets expiration date of the datapool entry to the specified value.
The value should be a relative time specification (such as '+000001',
which means one day). See OpenXPKI::DateTime::get_validity, section
'relativedate' for details.

If the expiration date is an emptry string, the expiration date is interpreted
as NULL.

=back

=head2 Arguments

=head2 Example


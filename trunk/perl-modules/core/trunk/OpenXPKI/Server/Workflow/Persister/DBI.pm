# OpenXPKI Workflow Persister
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision: 80 $

package OpenXPKI::Server::Workflow::Persister::DBI;

use strict;
use base qw( Workflow::Persister );
# use Smart::Comments;

use OpenXPKI::Server::Workflow::Persister::DBI::SequenceId;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;


sub init {
    my $self = shift;
    my $params = shift;
    
    $self->SUPER::init( $params );

    $self->assign_generators( $params );

    CTX('log')->log(
	MESSAGE  => "Assigned workflow generator '" 
	. ref( $self->workflow_id_generator ) . "'; "
	. "history generator '"
	. ref( $self->history_id_generator ),
	PRIORITY => "info",
	FACILITY => "system"
	);
    return 1;
}

sub create_workflow {
    my $self = shift;
    my $workflow = shift;
    ### create_workflow called...

    my $id = $self->workflow_id_generator->pre_fetch_id();

    ### workflow id: $id

    my $dbi = CTX('dbi_workflow');

    my %data = (
	WORKFLOW_TYPE        => $workflow->type(),
	WORKFLOW_STATE       => $workflow->state(),
	WORKFLOW_LAST_UPDATE => DateTime->now->strftime( '%Y-%m-%d %H:%M' ),
	);

    if ($id) {
	$data{WORKFLOW_SERIAL} = $id;
    }

    ### inserting data into workflow table
    $dbi->insert(
	TABLE => "WORKFLOW", 
	HASH => \%data,
	);

    if (! $id) {
	$id = $self->workflow_id_generator->post_fetch_id();
	if (! $id) {
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_NO_ID_FROM_SEQUENCE",
		params  => {
		    GENERATOR    => ref( $self->workflow_id_generator ),
		},
		);
	}
    }

    $dbi->commit();

    CTX('log')->log(
	MESSAGE  => "Created workflow $id",
	PRIORITY => "info",
	FACILITY => "system"
	);

    return $id;
}

sub update_workflow {
    my $self = shift;
    my $workflow = shift;

    ### update_workflow called...


}

sub fetch_workflow {
    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_NOT_IMPLEMENTED",
	params  => {
	    METHOD    => 'fetch_workflow',
	},
	);
}

sub create_history {
    my $self = shift;
    my $workflow = shift;
    my @history = @_;

    ### create_history called...
    my $generator = $self->history_id_generator();
    my $dbi = CTX('dbi_workflow');

  HISTORY_ENTRY:
    foreach my $entry (@history) {
	next HISTORY_ENTRY if ($entry->is_saved());

	my $id = $generator->pre_fetch_id();
	
	### workflow history id: $id

	my %data = (
	    WORKFLOW_SERIAL          => $workflow->id(),
	    WORKFLOW_ACTION          => $entry->action(),
	    WORKFLOW_DESCRIPTION     => $entry->description(),
	    WORKFLOW_STATE           => $entry->state(),
	    WORKFLOW_USER            => $entry->user(),
	    WORKFLOW_HISTORY_DATE    => DateTime->now->strftime( '%Y-%m-%d %H:%M' ),
	    );

	if ($id) {
	    $data{WORKFLOW_HISTORY_SERIAL} = $id;
	}

	### inserting data into workflow history table
	$dbi->insert(
	    TABLE => "WORKFLOW_HISTORY", 
	    HASH => \%data,
	    );
	
	if (! $id) {
	    $id = $generator->post_fetch_id();
	    
	    if (! $id) {
		OpenXPKI::Exception->throw (
		    message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_NO_ID_FROM_SEQUENCE",
		    params  => {
			GENERATOR    => ref( $self->workflow_id_generator ),
		    },
		    );
	    }
	}

	$entry->id($id);
	$entry->set_saved();

	CTX('log')->log(
	    MESSAGE  => "Created workflow history entry $id",
	    PRIORITY => "info",
	    FACILITY => "system"
	    );
    }

    $dbi->commit();

    return @history;
}


sub fetch_history {
    ### fetch_history called...
    OpenXPKI::Exception->throw (
	message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_NOT_IMPLEMENTED",
	params  => {
	    METHOD    => 'fetch_history',
	},
	);
}


### get sequence generators
sub assign_generators {
    my $self = shift;
    my $params = shift;

    $self->SUPER::assign_generators( $params );

    return if ( $self->workflow_id_generator and
                $self->history_id_generator );
    
    ### assigning ID generators for OpenXPKI DBI...
    my ( $wf_gen, $history_gen ) =
	$self->init_OpenXPKI_generators( $params );

    $self->workflow_id_generator( $wf_gen );
    $self->history_id_generator( $history_gen );
}


sub init_OpenXPKI_generators {
    my $self = shift;
    my $params = shift;
    $params->{workflow_table} ||= 'WORKFLOW';
    $params->{history_table} ||= 'WORKFLOW_HISTORY';

    return (
	OpenXPKI::Server::Workflow::Persister::DBI::SequenceId->new( 
	    {
		table_name => $params->{workflow_table},
	    },
	),
	OpenXPKI::Server::Workflow::Persister::DBI::SequenceId->new( 
	    {
		table_name => $params->{history_table},
	    },
	),
	);
}


1;

=head1 Description

Implements the OpenXPKI Workflow persister using the OpenXPKI DBI 
infrastructure. We do not subclass the Workflow::Persister::DBI here
because we'd like to have a single SQL abstraction layer in the
main DBI module.

For a description of the exported functions please refer to the Workflow
module documentation.

=head1 Functions

=head2 init

Initializes the persister (assigns sequence generators).

=head2 create_workflow

Creates a workflow instance object.

=head2 fetch_workflow

Fetches a workflow instance object from the persistant storage.

=head2 update_workflow

Updates a workflow instance object in persistant storage.

=head2 create_history

Creates a workflow history entry.

=head2 fetch_history

Fetches a workflow history object from the persistant storage.

=head2 assign_generators

Assigns sequence generators for workflow and history objects.

=head2 init_OpenXPKI_generators

Fetches sequence generators from the OpenXPKI database abstraction layer.



# OpenXPKI::Server::Workflow::Persister::DBI
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project
# $Revision$

package OpenXPKI::Server::Workflow::Persister::DBI;

use strict;
use base qw( Workflow::Persister );
use utf8;

use OpenXPKI::Debug 'OpenXPKI::Server::Workflow::Persister::DBI';

use OpenXPKI::Server::Workflow::Persister::DBI::SequenceId;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use DateTime::Format::Strptime;

my $workflow_table = 'WORKFLOW';
my $context_table  = 'WORKFLOW_CONTEXT';
my $history_table  = 'WORKFLOW_HISTORY';

# limits
my $context_value_max_length = 32768;

# tools
my $parser = DateTime::Format::Strptime->new( pattern => '%Y-%m-%d %H:%M' );

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

    return; # no useful return value
}

sub create_workflow {
    my $self = shift;
    my $workflow = shift;
    ##! 1: "create workflow"

    my $id = $self->workflow_id_generator->pre_fetch_id();

    ##! 1: "workflow id: $id"

    my $dbi = CTX('dbi_workflow');

    my %data = (
	PKI_REALM            => CTX('session')->get_pki_realm(),
	WORKFLOW_TYPE        => $workflow->type(),
	WORKFLOW_STATE       => $workflow->state(),
	WORKFLOW_LAST_UPDATE => DateTime->now->strftime( '%Y-%m-%d %H:%M' ),
	);

    if ($id) {
	$data{WORKFLOW_SERIAL} = $id;
    }

    ##! 1: "inserting data into workflow table"
    $dbi->insert(
	TABLE => $workflow_table,
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
    
    ##! 1: "update_workflow"

    my $id = $workflow->id();
    
    my %data = (
	WORKFLOW_STATE       => $workflow->state(),
	WORKFLOW_LAST_UPDATE => DateTime->now->strftime( '%Y-%m-%d %H:%M' ),
	);
    
    my $dbi = CTX('dbi_workflow');
    
    # save workflow instance...
    $dbi->update(
	TABLE  => $workflow_table,
	DATA   => \%data,
	WHERE  => {
	    WORKFLOW_SERIAL => $id,
	},
	);
    
    # ... purge any existing context data...
    $dbi->delete(TABLE => $context_table,
 		 DATA  => {
 		     WORKFLOW_SERIAL => $id,
 		 },
 	);
    
    # ... and write new context
    my $params = $workflow->context()->param();

  PARAMETER:
    while (my ($key, $value) = each %{ $params }) {
	# parameters with undefined values are not stored
	next PARAMETER if (! defined $value);

	##! 2: "persisting context parameter: $key"
	# ignore "volatile" context parameters starting with an underscore
	next PARAMETER if ($key =~ m{ \A _ }xms);

	# context parameter sanity checks 
	if (length($value) > $context_value_max_length) {
	    ##! 4: "parameter length exceeded"
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_UPDATE_WORKFLOW_CONTEXT_VALUE_TOO_BIG",
		params  => {
		    WORKFLOW_ID => $id,
		    CONTEXT_KEY => $key,
		    CONTEXT_VALUE_LENGTH => length($value),
		},
		);
	}

	# check for illegal characters
	if ($value =~ m{ (?:\p{Unassigned}|\x00) }xms) {
	    ##! 4: "parameter contains illegal characters"
	    OpenXPKI::Exception->throw (
		message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_UPDATE_WORKFLOW_CONTEXT_VALUE_ILLEGAL_DATA",
		params  => {
		    WORKFLOW_ID => $id,
		    CONTEXT_KEY => $key,
		},
		);
	}
	
	##! 2: "saving context for wf: $id"
 	$dbi->insert(
 	    TABLE => $context_table,
 	    HASH => {
 		WORKFLOW_SERIAL        => $id,
 		WORKFLOW_CONTEXT_KEY   => $key,
 		WORKFLOW_CONTEXT_VALUE => $value
 	    }
 	    );
    }
    
    $dbi->commit();
    
    CTX('log')->log(
	MESSAGE  => "Updated workflow $id",
	PRIORITY => "info",
	FACILITY => "system"
	);

    return 1;
}

sub fetch_workflow {
    my $self = shift;
    my $id   = shift;

    ##! 1: "fetch_workflow"
    ##! 1: "workflow id: $id"

    my $dbi = CTX('dbi_workflow');

    my $result = $dbi->get(
	TABLE => $workflow_table,
	SERIAL => $id,
	DYNAMIC => {
	    PKI_REALM  => CTX('session')->get_pki_realm(),
	},
	);
    
    if (! $result ||
	(! $result->{WORKFLOW_STATE}) ||
	(! $result->{WORKFLOW_LAST_UPDATE})) {
	CTX('log')->log(
	    MESSAGE  => "Could not retrieve workflow entry $id",
	    PRIORITY => "error",
	    FACILITY => "system"
	    );

	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_FETCH_WORKFLOW_NOT_FOUND",
	    params  => {
		WORKFLOW_ID => $id,
	    },
	    );
    }

    # numerical comparison enforced, serials are always numbers
    if ($result->{WORKFLOW_SERIAL} != $id) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_FETCH_WORKFLOW_INCORRECT_WORKFLOW_INSTANCE",
	    params  => {
		REQUESTED_ID => $id,
		RETURNED_ID  => $result->{WORKFLOW_SERIAL},
	    },
	    );
    }

    return({
	state       => $result->{WORKFLOW_STATE},
	last_update => $parser->parse_datetime($result->{WORKFLOW_LAST_UPDATE}),
	   });
}


sub fetch_extra_workflow_data {
    my $self     = shift;
    my $workflow = shift;

    ##! 1: "fetch_extra_workflow_data"
    my $id = $workflow->id();
    my $dbi = CTX('dbi_workflow');

    my $result = $dbi->select(
	TABLE   => $context_table,
	DYNAMIC => {
	    WORKFLOW_SERIAL => $id,
	},
	);

    # NOTE: work around a bug in Workflow::Context up to and including v0.17:
    # clear context in order to prevent merging operation when attaching
    # the new context to the workflow instance below.
    if ($Workflow::Context::VERSION <= 1.03) {
	# Workflow::Context workaround
	##! 2: "explicitly clear all context entries"
	$workflow->context()->clear_params();

	# set workflow ID (for compatibility with the non-workaround 
	# version below)
	$workflow->context()->param(workflow_id => $id);

	foreach my $entry (@{$result}) {
	    $workflow->context()->param($entry->{WORKFLOW_CONTEXT_KEY} =>
					$entry->{WORKFLOW_CONTEXT_VALUE});
	}
    } else {
	# new empty context
	my $context = Workflow::Context->new();
	foreach my $entry (@{$result}) {
	    $context->param($entry->{WORKFLOW_CONTEXT_KEY} =>
			    $entry->{WORKFLOW_CONTEXT_VALUE});
	}

	# merge context to workflow instance
	$workflow->context($context);
    }

    return; # no useful result
}




sub create_history {
    my $self = shift;
    my $workflow = shift;
    my @history = @_;

    ##! 1: "create_history"
    my $generator = $self->history_id_generator();
    my $dbi = CTX('dbi_workflow');

  HISTORY_ENTRY:
    foreach my $entry (@history) {
	next HISTORY_ENTRY if ($entry->is_saved());

	my $id = $generator->pre_fetch_id();
	
	##! 2: "workflow history id: $id"

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

	##! 2: "inserting data into workflow history table"
	$dbi->insert(
	    TABLE => $history_table,
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
    my $self = shift;
    my $workflow = shift;

    ##! 1: "fetch_history"
    my $id = $workflow->id();
    my $dbi = CTX('dbi_workflow');

    # get all history objects for workflow $id, sorted descending by
    # creation date

    my @history = ();
    
    my $entry = $dbi->last(
	TABLE           => $history_table,
	WORKFLOW_SERIAL => $id,
	);

    # FIXME: get history sorted by timestamp (see Workflow::Persister::DBI)
    while ($entry) {
	my $histid = $entry->{WORKFLOW_HISTORY_SERIAL};
        my $hist = Workflow::History->new(
	    {
		id          => $histid,
		workflow_id => $entry->{WORKFLOW_SERIAL},
		action      => $entry->{WORKFLOW_ACTION},
		description => $entry->{WORKFLOW_DESCRIPTION},
		state       => $entry->{WORKFLOW_STATE},
		user        => $entry->{WORKFLOW_USER},
		date        => $parser->parse_datetime($entry->{WORKFLOW_LAST_UPDATE}),
	    });

	CTX('log')->log(
	    MESSAGE  => "Fetched history object '$histid'",
	    PRIORITY => "debug",
	    FACILITY => "system"
	    );
	
        $hist->set_saved();
        push @history, $hist;     

	$entry = $dbi->prev(
	    TABLE           => $history_table,
	    WORKFLOW_SERIAL => $id,
	    );
	
    }

    return @history;
}


sub assign_generators {
    my $self = shift;
    my $params = shift;

    $self->SUPER::assign_generators( $params );

    return if ( $self->workflow_id_generator and
                $self->history_id_generator );
    
    ##! 2: "assigning ID generators for OpenXPKI DBI"
    my ( $wf_gen, $history_gen ) =
	$self->init_OpenXPKI_generators( $params );

    $self->workflow_id_generator( $wf_gen );
    $self->history_id_generator( $history_gen );
}


sub init_OpenXPKI_generators {
    my $self = shift;
    my $params = shift;
    $params->{workflow_table} ||= $workflow_table;
    $params->{history_table}  ||= $history_table;

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
__END__

=head1 Name

OpenXPKI::Server::Workflow::Persister::DBI

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

=head2 fetch_extra_workflow_data

Fetches a workflow's context from persistant storage.

=head2 update_workflow

Updates a workflow instance object in persistant storage.

Limitation: Context values must consist of valid Unicode characters.
NULL bytes are explicitly not allowed. Binary data storage is NOT possible.

Limitation: The maximum length of context values is 32 KByte.

Limitation: If the parameter value is 'undef' the parameter will not be
persisted. After restoring the workflow instance from persistent storage
the corresponding entry will not exist.

=head3 Volatile Context Parameters 

Context parameters starting with an underscore '_' will NOT be 
saved persistently in the database. You can use such parameters
for storing truly temporary data that does not need to be stored in the
database (and that will NOT survive saving and retrieving the workflow
instance from the database!) or e. g. for caching objects that can also be
retrieved from the database.

Such volatile context parameters can have arbitrary size, may contain
arbitrary Perl data structures (including Object references) or arbitrary
binary data.

=head2 create_history

Creates a workflow history entry.

=head2 fetch_history

Fetches a workflow history object from the persistant storage.

=head2 assign_generators

Assigns sequence generators for workflow and history objects.

=head2 init_OpenXPKI_generators

Fetches sequence generators from the OpenXPKI database abstraction layer.



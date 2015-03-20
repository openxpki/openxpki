# OpenXPKI::Server::Workflow::Persister::DBI
# Written by Martin Bartosch for the OpenXPKI project 2005
# Copyright (c) 2005 by The OpenXPKI Project

package OpenXPKI::Server::Workflow::Persister::DBI;

use strict;
use base qw( Workflow::Persister );
use utf8;
use English;

# use Smart::Comments;

use OpenXPKI::Debug;

use OpenXPKI::Server::Workflow::Persister::DBI::SequenceId;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Serialization::Simple;
use DateTime::Format::Strptime;

use Data::Dumper;

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
    ##! 1: "create workflow (only id)"

    my $id = $self->workflow_id_generator->pre_fetch_id();

    ##! 2: "BTW we shredder many workflow IDs here"

    CTX('log')->log(
    	MESSAGE  => "Created workflow ID $id.",
    	PRIORITY => "info",
    	FACILITY => "workflow"
	);

    return $id;
}

sub update_workflow {
    my $self = shift;
    my $workflow = shift;
    
    ##! 1: "update_workflow"

    my $id   = $workflow->id();
    my $dbi  = CTX('dbi_workflow');
    my %data = (
	   WORKFLOW_STATE       => $workflow->state(),
	   WORKFLOW_LAST_UPDATE => DateTime->now->strftime( '%Y-%m-%d %H:%M:%S' ),
	   
	   WORKFLOW_PROC_STATE  => $workflow->proc_state(),
	   
	   WORKFLOW_WAKEUP_AT   => $workflow->wakeup_at() || 0,
	   WORKFLOW_COUNT_TRY   => $workflow->count_try(),
	   WORKFLOW_REAP_AT     => $workflow->reap_at() || 0,
	   WORKFLOW_SESSION     => $workflow->session_info(),
           # always reset the watchdog key, if the workflow is updated from within
           # the API/Factory, as the worlds most famous db system is unable to 
           # handle NULL values we use a literal....
	   WATCHDOG_KEY         => '__CATCHME', 
	);
    
    
    ##! 2: "check if the workflow is in the database"

    my $mode = 'UPDATE';
    eval
    { 
        my $oldwf = $self->fetch_workflow ($id);
	### $oldwf
	### $EVAL_ERROR
    };
    if (my $exc = OpenXPKI::Exception->caught()) {
	if ($exc->message() eq 'I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_FETCH_WORKFLOW_NOT_FOUND') {
	    $mode = 'INSERT';
	} else {
	    ### $exc->full_message()
	    $exc->rethrow();
	}
    } elsif ($EVAL_ERROR) {
	OpenXPKI::Exception->throw (
	    message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_UPDATE_WORKFLOW_FETCH_WORKFLOW_FAILURE",
	    params  => {EVAL_ERROR => $EVAL_ERROR});
    }
    
    if ($mode eq 'INSERT')
    {
	
        ##! 4: "we cannot get the workflow so we try to create it"
        $data{PKI_REALM}          = CTX('session')->get_pki_realm();
        $data{WORKFLOW_TYPE}   = $workflow->type();
        $data{WORKFLOW_SERIAL} = $id;
        

        ##! 1: "inserting data into workflow table"
        $dbi->insert(
            TABLE => 'WORKFLOW',
            HASH  => \%data,
        );

        CTX('log')->log(
            MESSAGE  => "Created workflow $id",
            PRIORITY => "info",
            FACILITY => "system"
        );
    }
    else
    {
        ##! 4: "really update the workflow"
        ##! 128: 'data: ' . Dumper(\%data)

        # save workflow instance...
        $dbi->update(
            TABLE  => 'WORKFLOW',
            DATA   => \%data,
            WHERE  => {
                WORKFLOW_SERIAL => $id,
            },
        );
        ##! 128: 'update done'
    }
    
    # ... and write new context / update it
    my $params = $workflow->context()->param();

    ##! 128: 'params from context: ' . Dumper $params
  PARAMETER:
    foreach my $key (keys %{ $params }) {
        my $value = $params->{$key};
        # parameters with undefined values are not stored / deleted
        if (! defined $value) {
            # TODO - figure out if deletion is really necessary?
            # HEAD does not have the delete part ...
            ##! 4: 'value for key ' . $key . ' is undef, try to delete'
            eval {
                $dbi->delete(
                    TABLE => 'WORKFLOW_CONTEXT',
                    DATA  => {
                        WORKFLOW_SERIAL        => $id,
                        WORKFLOW_CONTEXT_KEY   => $key,
                    },
                );
            };
            next PARAMETER;
        }

    	##! 2: "persisting context parameter: $key"
    	# ignore "volatile" context parameters starting with an underscore
    	next PARAMETER if ($key =~ m{ \A _ }xms);

        # automatic serialization        
        if (ref $value eq 'ARRAY' ||  ref $value eq 'HASH') {
            my $ser = OpenXPKI::Serialization::Simple->new();
            $value = $ser->serialize( $value );
        }
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
            log => {
                logger => CTX('log'),
                priority => 'error',
                facility => 'system',
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
            log => {
                logger => CTX('log'),
                priority => 'error',
                facility => [ 'audit', 'system', ],
            },
            );
        }
        
        ##! 2: "saving context for wf: $id"
        ##! 16: 'trying to update context entry'
        my $rows_changed = $dbi->update(
            TABLE   => 'WORKFLOW_CONTEXT',
            DATA    => {
                WORKFLOW_SERIAL        => $id,
                WORKFLOW_CONTEXT_KEY   => $key,
                WORKFLOW_CONTEXT_VALUE => $value,
            },
            WHERE => {
                WORKFLOW_SERIAL      => $id,
                WORKFLOW_CONTEXT_KEY => $key,
            },
        );
        ##! 128: 'update done, key: ' . $key . ', value: ' . $value

        if ($rows_changed == 0) {
            ##! 16: 'update did not work, possibly new key, try insert'
            $dbi->insert(
                TABLE => 'WORKFLOW_CONTEXT',
                HASH => {
                    WORKFLOW_SERIAL        => $id,
                    WORKFLOW_CONTEXT_KEY   => $key,
                    WORKFLOW_CONTEXT_VALUE => $value
                }
            );
            ##! 128: 'insert done, key: ' . $key . ', value: ' . $value
        }
    }
    
    $dbi->commit();
    
    CTX('log')->log(
        MESSAGE  => "Updated workflow $id",
        PRIORITY => "info",
        FACILITY => "workflow"
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
	TABLE => 'WORKFLOW',
	SERIAL => $id,
	DYNAMIC => {
	    PKI_REALM  => {VALUE => CTX('session')->get_pki_realm()},
	},
	);
    ### $result

    if (! $result ||
	(! $result->{WORKFLOW_STATE}) ||
	(! $result->{WORKFLOW_LAST_UPDATE})) {
	CTX('log')->log(
	    MESSAGE  => "Could not retrieve workflow entry $id",
	    PRIORITY => "warn",
	    FACILITY => "workflow"
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
	    log => {
		logger => CTX('log'),
		priority => 'warn',
		facility => 'system',
	    },
	    );
    }
    
    my $return = {
	       state       => $result->{WORKFLOW_STATE},
	       last_update => $parser->parse_datetime($result->{WORKFLOW_LAST_UPDATE}),
	       proc_state  => $result->{WORKFLOW_PROC_STATE},
	       count_try   => $result->{WORKFLOW_COUNT_TRY},
	       wakeup_at   => $result->{WORKFLOW_WAKEUP_AT},
	       reap_at   => $result->{WORKFLOW_REAP_AT},
	   };
    
    ##! 1: "return ".Dumper($return);
    
    return $return;
}


sub fetch_extra_workflow_data {
    my $self     = shift;
    my $workflow = shift;

    ##! 1: "fetch_extra_workflow_data"
    my $id = $workflow->id();
    my $dbi = CTX('dbi_workflow');

    my $result = $dbi->select(
	TABLE   => 'WORKFLOW_CONTEXT',
	DYNAMIC => {
	    WORKFLOW_SERIAL => {VALUE => $id},
	},
	);

    # new empty context
    my $context = Workflow::Context->new();
    
    my $ser = OpenXPKI::Serialization::Simple->new();
    
    foreach my $entry (@{$result}) {
        
        my $key = $entry->{WORKFLOW_CONTEXT_KEY};
        my $val = $entry->{WORKFLOW_CONTEXT_VALUE};
        
        if ($ser->is_serialized( $val )) {
            ##! 8: "auto deserialize $key"            
            $val = $ser->deserialize($val);
        }
        $context->param( $key => $val );
    }
    
    # merge context to workflow instance
    $workflow->context($context);

    return 1; 
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
	    WORKFLOW_HISTORY_DATE    => DateTime->now->strftime( '%Y-%m-%d %H:%M:%S' ),	    
	    );

	if ($id) {
	    $data{WORKFLOW_HISTORY_SERIAL} = $id;
	}
        if ($entry->user() eq 'n/a')
        {
            ## user set by workflow factory class
            $data{WORKFLOW_USER} = CTX('session')->get_user();
        }

	##! 2: "inserting data into workflow history table"
	$dbi->insert(
	    TABLE => 'WORKFLOW_HISTORY',
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
	    PRIORITY => "debug",
	    FACILITY => "workflow"
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
	TABLE           => 'WORKFLOW_HISTORY',
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
	    FACILITY => "workflow"
	    );
	
        $hist->set_saved();
        push @history, $hist;     

	$entry = $dbi->prev(
	    TABLE           => 'WORKFLOW_HISTORY',
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
    $params->{workflow_table} ||= 'WORKFLOW';
    $params->{history_table}  ||= 'WORKFLOW_HISTORY';

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



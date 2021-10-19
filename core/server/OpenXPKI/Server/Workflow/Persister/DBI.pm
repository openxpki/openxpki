package OpenXPKI::Server::Workflow::Persister::DBI;

use strict;
use base qw( Workflow::Persister );
use utf8;
use English;

use Sys::Hostname;
use OpenXPKI::Debug;

use OpenXPKI::Workflow::Context;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Serialization::Simple;
use OpenXPKI::Exception;
use DateTime;
use DateTime::Format::Strptime;

use Data::Dumper;

# my @FIELDS = qw( );
# __PACKAGE__->mk_accessors(@FIELDS);

# limits
my $context_value_max_length = 32768;

# tools
my $parser = DateTime::Format::Strptime->new(
    pattern  => '%Y-%m-%d %H:%M:%S',
    on_error => sub { OpenXPKI::Exception->throw(
        message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_PARSE_DATE_ERROR",
    )},
);

sub init {
    my ($self, $params) = @_;
    # for (@FIELDS) {
    #     $self->$_( $params->{$_} ) if $params->{$_};
    # }
    $self->SUPER::init($params);
    return; # no useful return value
}

sub create_workflow {
    my $self     = shift;
    my $workflow = shift;
    ##! 1: "create workflow (only id)"

    my $id = CTX('dbi')->next_id('workflow');

    ##! 2: "Next id $id - we shredder many workflow IDs here"

    CTX('log')->workflow()->info("Created workflow ID $id.");


    return $id;
}

sub update_workflow {
    my ($self, $workflow) = @_;

    my $id  = $workflow->id;
    ##! 1: "Saving WF #$id to DB"
    my $dbi = CTX('dbi');

    $self->__update_workflow($workflow);

    if ($workflow->persist_context) {
        $self->__update_workflow_context($workflow) ;

        if ($workflow->persist_context > 1) {
            $self->__update_workflow_attributes($workflow) ;
            # Reset the update marker (after COMMIT) if full update was requested
            $workflow->context->reset_updated;
        }
    }

    CTX('log')->workflow()->debug( "Updated workflow $id");
}

sub __update_workflow {
    my ($self, $workflow) = @_;

    my $id  = $workflow->id;
    ##! 16: sprintf "WF #$id: saving workflow, state: %s, proc_state: %s", $workflow->state(), $workflow->proc_state()

    # save user info so Watchdog is able to resume workflow in correct context
    my $workflow_session = CTX('session')->data->freeze(only => [ "user", "role" ]);

    CTX('dbi')->merge(
        into => 'workflow',
        set  => {
            workflow_state       => $workflow->state,
            workflow_last_update => DateTime->now->strftime('%Y-%m-%d %H:%M:%S'),
            workflow_proc_state  => $workflow->proc_state,
            workflow_wakeup_at   => $workflow->wakeup_at || 0,
            workflow_count_try   => $workflow->count_try,
            workflow_reap_at     => $workflow->reap_at || 0,
            workflow_session     => $workflow_session,
            workflow_archive_at  => $workflow->archive_at,
            # always reset the watchdog key, if the workflow is updated from within
            # the API/Factory, as the worlds most famous db system is unable to
            # handle NULL values we use a literal....
            watchdog_key => '__CATCHME',
        },
        set_once => {
            pki_realm => CTX('session')->data->pki_realm,
            workflow_type => $workflow->type,
        },
        where => {
            workflow_id   => $id,
        }
    );
}

sub __update_workflow_context {
    my ($self, $workflow) = @_;

    my $id  = $workflow->id;
    my $context = $workflow->context;
    my $params  = $context->param;
    my $dbi = CTX('dbi');

    ##! 32: "WF #$id: Context is " . ref $context
    ##! 128: "WF #$id: Params from context: " . Dumper $params
    my @updated = keys %{ $context->{_updated} };

    ##! 32: "WF #$id: Params with updates: " . join(":", @updated )
    # persist only the internal context values
    if ($workflow->persist_context == 1) {
        @updated = grep { /^wf_/ } @updated;
        ##! 32: "WF #$id: Only update internals " . join(":", @updated )
    }

    # do not persit the virtual workflow_id/creator/tenant field
    # ignore "volatile" context parameters starting with an underscore
    @updated = grep { $_ !~ /\A(_.+|creator|workflow_id|tenant)\z/ } @updated;

    for my $key (@updated) {
        my $value = $params->{$key};

        # parameters with undefined values are not stored / deleted
        if (not defined $value ) {
            ##! 2: "DELETING context key: $key => undef"
            $dbi->delete(
                from  => 'workflow_context',
                where => {
                    workflow_id          => $id,
                    workflow_context_key => $key,
                },
            );
            next;
        }

        # automatic serialization
        if ( ref $value eq 'ARRAY' or ref $value eq 'HASH' ) {
            $value = OpenXPKI::Serialization::Simple->new->serialize($value);
        }

        ##! 16: "  saving context key: $key => $value"
        # check for illegal characters
        if ( $value =~ m{ (?:\p{Unassigned}|\x00) }xms ) {
            ##! 4: "parameter contains illegal characters"
            $dbi->rollback;
            OpenXPKI::Exception->throw(
                message => "Illegal data in workflow context persister",
                params => {
                    workflow_id => $id,
                    context_key => $key,
                },
                log => {
                    priority => 'fatal',
                    facility => 'workflow',
                },
            );
        }

        $dbi->merge(
            into => 'workflow_context',
            set  => {
                workflow_context_value => $value,
            },
            where => {
                workflow_id          => $id,
                workflow_context_key => $key,
            },
        );
    }
}

sub __update_workflow_attributes {
    my ($self, $workflow) = @_;

    my $id  = $workflow->id;
    my $attrs = $workflow->attrib;
    my $dbi = CTX('dbi');

    for my $key (keys %{$attrs}) {
        # delete if value = undef
        if (not defined $attrs->{$key}) {
            ##! 2: "DELETING attribute: $key => undef"
            $dbi->delete(
                from => 'workflow_attributes',
                where => {
                    workflow_id          => $id,
                    attribute_contentkey => $key,
                },
            );
            next;
        }

        my $value = $attrs->{$key};

        # non scalar values are not allowed
        OpenXPKI::Exception->throw(
            message => 'Attempt to persist non-scalar workflow attribute',
            params => { key => $key, type => ref $value }
        ) if ref $value ne '';

        ##! 2: "saving attribute: $key => $value"
        $dbi->merge(
            into => 'workflow_attributes',
            set => {
                attribute_value      => $attrs->{$key},
            },
            where => {
                workflow_id          => $id,
                attribute_contentkey => $key,
            },
        );
    }
}

sub fetch_workflow {
    my $self = shift;
    my $id   = shift;

    ##! 1: "id = $id"

    my $dbi = CTX("dbi");

    my $result = $dbi->select_one(
        from => 'workflow',
        columns => [ qw(
            workflow_state
            workflow_last_update
            workflow_proc_state
            workflow_count_try
            workflow_wakeup_at
            workflow_reap_at
            workflow_archive_at
        ) ],
        where => {
            workflow_id => $id,
            pki_realm => CTX('session')->data->pki_realm,
        },
    );

    if (not ($result and $result->{workflow_state} and $result->{workflow_last_update}) ) {
        CTX('log')->workflow()->warn("Could not retrieve workflow #$id");

        OpenXPKI::Exception->throw(
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_PERSISTER_DBI_FETCH_WORKFLOW_NOT_FOUND",
            params => { workflow_id => $id },
        );
    }

    my $return = {
        state       => $result->{workflow_state},
        last_update => $parser->parse_datetime( $result->{workflow_last_update} ),
        proc_state  => $result->{workflow_proc_state},
        count_try   => $result->{workflow_count_try},
        wakeup_at   => $result->{workflow_wakeup_at},
        reap_at     => $result->{workflow_reap_at},
        archive_at  => $result->{workflow_archive_at},
        context     => OpenXPKI::Workflow::Context->new(),
    };

    ##! 64: "return ".Dumper($return);
    return $return;
}

# Called by Workflow::Factory->fetch_workflow(), overwrites empty impl. in Workflow::Persister
sub fetch_extra_workflow_data {
    my ($self, $workflow) = @_;
    ##! 1: "fetch_extra_workflow_data"
    my $id  = $workflow->id();
    my $dbi = CTX('dbi');

    # Context
    my $sth = $dbi->select(
        from => "workflow_context",
        columns => [ "workflow_context_key", "workflow_context_value" ],
        where => { workflow_id => $id },
    );
    # context was set in fetch_workflow
    my $context = $workflow->context();
    $context->{_init} = 1;
    while (my $row = $sth->fetchrow_arrayref) {
        ##! 32: "Setting context param: ".$row->[0]." => ".$row->[1]
        $context->param($row->[0] => $row->[1]);
    }
    $context->{_init} = 0;

    # Attributes
    $sth = $dbi->select(
        from => 'workflow_attributes',
        columns => [ 'attribute_contentkey', 'attribute_value' ],
        where => { workflow_id => $id },
    );
    my $attrs = {};
    while (my $row = $sth->fetchrow_arrayref) {
        ##! 32: "Setting attribute: ".$row->[0]." => ".$row->[1]
        $attrs->{$row->[0]} = $row->[1];
    }
    $workflow->attrib($attrs);

    # add "virtual" creator and tenant
    $context->param( 'creator' => $attrs->{creator} );
    $context->param( 'tenant' => $attrs->{tenant} ) if ($attrs->{tenant});

    # clear the updated flag
    $context->reset_updated();

}

sub create_history {
    my $self     = shift;
    my $workflow = shift;
    my @history  = @_;

    return if ($workflow->proc_state eq 'init');

    ##! 1: "create_history"
    my $dbi       = CTX('dbi');

    foreach my $entry (@history) {
        ##! 64: 'Persisting history ' . Dumper $entry
        next if $entry->is_saved;

        my $id = $dbi->next_id('workflow_history');
        ##! 8: "workflow history id: $id"

        ##! 2: "inserting data into workflow history table"
        $dbi->insert(
            into => 'workflow_history',
            values => {
                workflow_hist_id      => $id,
                workflow_id           => $workflow->id(),
                workflow_action       => $entry->action(),
                workflow_description  => $entry->description(),
                workflow_state        => $entry->state(),
                ## user set by workflow factory class
                workflow_user         => ($entry->user ne 'n/a' ? $entry->user : CTX('session')->data->user),
                workflow_history_date => DateTime->now->strftime('%Y-%m-%d %H:%M:%S'),
                workflow_node         => hostname,
            },
        );

        $entry->id($id);
        $entry->set_saved;

        CTX('log')->workflow()->debug("Created workflow history entry $id");
    }

    return @history;
}

sub fetch_history {
    my $self     = shift;
    my $workflow = shift;

    ##! 1: "fetch_history"
    my $id  = $workflow->id();
    my $dbi = CTX('dbi');

    # get all history objects for workflow $id, sorted descending by
    # creation date

    my @history = ();

    my $sth = $dbi->select(
        from => 'workflow_history',
        columns => [ qw(
            workflow_hist_id
            workflow_id
            workflow_action
            workflow_description
            workflow_state
            workflow_user
            workflow_history_date
            workflow_node
        ) ],
        order_by => [ '-workflow_history_date' ],
        where => { workflow_id => $id },
    );

    # FIXME: get history sorted by timestamp (see Workflow::Persister::DBI)
    while (my $entry = $sth->fetchrow_hashref) {
        my $histid = $entry->{workflow_hist_id};
        my $hist   = Workflow::History->new({
            id          => $histid,
            workflow_id => $entry->{workflow_id},
            action      => $entry->{workflow_action},
            description => $entry->{workflow_description},
            state       => $entry->{workflow_state},
            user        => $entry->{workflow_user},
            date => $parser->parse_datetime( $entry->{workflow_history_date} ),
            node        => $entry->{workflow_node},
        });
        $hist->set_saved();
        push @history, $hist;
        CTX('log')->workflow()->debug("Fetched history object '$histid'");
    }

    return @history;
}

sub update_proc_state {

    my ($self, $wf_id, $old_state, $new_state) = @_;
    ##! 32: "Save proc_state $wf_id: $old_state => $new_state"

    my $row_count;
    eval {
        $row_count = CTX('dbi')->update(
            table => 'workflow',
            set => {
                workflow_proc_state => $new_state,
                workflow_last_update => DateTime->now->strftime( '%Y-%m-%d %H:%M:%S' ),
            },
            where => {
                workflow_proc_state => $old_state,
                workflow_id => $wf_id,
            },
        );
    };
    # We use DB transaction isolation level "READ COMMITTED":
    # So in the meantime another process might have changed the database.
    # Two things can happen:
    # 1. other process committed changes -> our update's where clause misses ($row_count = 0).
    # 2. other process did not commit -> timeout exception because of DB row lock
    if ($@ or $row_count < 1) {
        my $info = CTX('dbi')->select_one(
            from => 'workflow',
            columns => [ 'workflow_proc_state' ],
            where => { workflow_id => $wf_id },
        );
        CTX('log')->workflow->warn(sprintf(
            'Could not update workflow #%s to proc_state "%s". Expected previous state: "%s", found: "%s"',
            $wf_id, $new_state,$old_state, $info->{workflow_proc_state}
        ));
        return 0;
    }
    else {
        return 1;
    }
}

sub commit_transaction {
    ##! 1: "COMMIT"
    CTX('log')->workflow->debug("Executing database COMMIT (requested by workflow engine)");
    CTX('dbi')->commit;
    CTX('dbi')->start_txn;
    return;
}

sub rollback_transaction {
    ##! 1: "ROLLBACK"
    CTX('log')->workflow->debug("Executing database ROLLBACK (requested by workflow engine)");
    CTX('dbi')->rollback;
    CTX('dbi')->start_txn;
    return;
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

=head2 update_proc_state($old_state, $new_state)

Tries to update the C<proc_state> in the database to C<$new_state>.

Returns 1 on success and 0 if e.g. another parallel process already changed the
given C<$old_state>.


package OpenXPKI::Server::Workflow;

use base qw( Workflow );

use strict;
use warnings;
use utf8;
use English;
use Carp qw(croak carp);
use Scalar::Util 'blessed';
use Workflow::Exception qw( workflow_error );

use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Exception;
use OpenXPKI::Debug;
use OpenXPKI::Serialization::Simple;
use OpenXPKI::DateTime;

use Data::Dumper;

__PACKAGE__->mk_accessors( qw( proc_state count_try wakeup_at reap_at session_info persist_context ) );

my $default_reap_at_interval = '+0000000005';

my %known_proc_states = (

    #"action" defines, what should happen (=which hook-method sholuld be called), when execute_action is called on  this proc_state
    # example: if proc_state eq 'pause', '_wake_up' is called (IN current Activity-Object!)
    # 'none' means: no specail action needed (=no hook is called), process can go on
    #
    # '_runtime_exception' means: its not allowed (and should not be possible) to (re-)enter a
    # workflow with this proc_state (e.g 'finished' or 'wakeup').
    #
    # see "_handle_proc_state" for details

    init        => {desc => 'set in constructor, no action executed yet',
                    action=>'none'},
    wakeup      => {desc =>'wakeup after pause',
                    action=>'_runtime_exception'},
    resume      => {desc =>'resume after exception',
                    action=>'_runtime_exception'},
    running     => {desc =>'action executes',
                    action=>'none'},
    manual      => {desc =>'action stops regulary',
                    action=>'none'},
    finished    => {desc =>'action finished with success',
                    action=>'none'},#perfectly handled from WF-State-Engine
    pause       => {desc =>'action paused',
                    action=>'_wake_up'},
    exception   => {desc =>'an exception has been thrown',
                    action=>'_resume'},
    retry_exceeded => {desc =>'count of retries has been exceeded',
                    action=>'_resume'}

);

sub init {

    ##! 1: 'start'

    my ( $self, $id, $current_state, $config, $wf_state_objects, $factory ) = @_;

    $self->persist_context(0);

    $self->SUPER::init( $id, $current_state, $config, $wf_state_objects, $factory );

    $self->{_CURRENT_ACTION} = '';

    # Workflow attributes (should be stored by persistor class).
    # Values set to "undef" will be stored like that in $self->{_attributes},
    # so the persister knows that these shall be deleted from the storage.
    $self->{_attributes} = {};

    my $proc_state = 'init';
    my $count_try =  0;

    # For existing workflows - check for the watchdog extra fields
    if ($id) {
        my $persister = $self->_factory()->get_persister( $config->{persister} );
        my $wf_info   = $persister->fetch_workflow($id);

        # fetch additional infos from database:
        $count_try = $wf_info->{count_try} if ($wf_info->{count_try});
        $proc_state = $wf_info->{proc_state} if ($wf_info->{proc_state});

        $self->wakeup_at( $wf_info->{wakeup_at} );
        $self->reap_at( $wf_info->{reap_at} );
    }

    ##! 16: 'count try: '.$count_try
    $self->count_try( $count_try );
    $self->proc_state( $proc_state );

    return $self;
}

# we need to make sure that we always return a OXI::Context object
sub context {
    my ( $self, $context ) = @_;
    if (!$context && !$self->{context} ) {
        $self->{context} = OpenXPKI::Workflow::Context->new();
    }

    return $self->SUPER::context( $context );
}


sub execute_action {

    my ( $self, $action_name, $autorun ) = @_;
    ##! 1: 'execute_action '.$action_name

    # if we are in a recursive run or in an initial create the dbi
    # transaction is already open and the autorun flag is set
    if (!$autorun) {
        CTX('dbi')->start_txn;
    }

    $self->persist_context(1);

    $self->session_info(
        CTX('session')->data->freeze(only => [ "user", "role" ])
    );

    # The workflow module internally caches conditions and does NOT clear
    # this cache if you just refetch a workflow! As the workflow state
    # object is shares, this leads to wrong states in the condition cache
    # if you reopen two different workflows in the same state!

    my $wf_state = $self->_get_workflow_state->clear_condition_cache();


    #set "reap at" info
    my $action = $self->_get_action($action_name);

    $self->{_CURRENT_ACTION} = $action_name;
    $self->context->param( wf_current_action => $action_name );

    # reset context-key exception
    $self->context->param( wf_exception => undef ) if $self->context->param('wf_exception');

    # check and handle current proc_state
    $self->_handle_proc_state($action_name);

    my $reap_at_interval = $default_reap_at_interval;
    if (blessed( $action ) && $action->isa('OpenXPKI::Server::Workflow::Activity')) {
        $reap_at_interval = $action->get_reap_at_interval();
    }

    # skip auto-persist as this will happen on next call anyway
    $self->set_reap_at_interval($reap_at_interval, 1);

    ##! 16: 'set proc_state "running"'
    $self->_set_proc_state('running'); # writes workflow metadata

    CTX('log')->application()->info("Execute action $action_name on workflow #" . $self->id);


    my $state='';
    # the double eval construct is used, because the handling of a caught pause throws a runtime error as real exception,
    # if some strange error in the process flow ocurred (for example, if somebody manually "throws" a OpenXPKI::Server::Workflow::Pause object)

    my $e;

    $self->persist_context(2);
    ##! 16: 'Run super::execute_action'
    eval{
        $state = $self->SUPER::execute_action( $action_name, $autorun );

        # if we are here, anything should have been persisted and commited
        # by the workflow internals (execute_action in the upstream class
        # calls update_workflow and commit on the persister after each action)
    };

    ##! 16: 'super::execute_action returned'

    # As pause comes up with an exception we can never have pause + an extra exception
    # so we just ignore any expcetions here
    if ($self->_has_paused()) {
        ##! 16: 'action paused'
        # noop
    } elsif( $EVAL_ERROR ) {

        my $error = $EVAL_ERROR;

        ##! 16: 'action failed with error: ' .$error
        # Check for validation errors (dont set the workflow to exception)
        if (ref $error eq 'Workflow::Exception::Validation') {

            # nothing was persisted so far, no rollback required

            # We reset the flag to prevent the context to be persisted
            # when we reset the status now, see #236
            $self->persist_context(0);

            ##! 32: 'validator exception: ' . Dumper $error
            # Set workflow status to manual
            $self->_set_proc_state( 'manual' );

            my $invalid_fields = $error->{invalid_fields} || {};
            OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_SERVER_WORKFLOW_VALIDATION_FAILED_ON_EXECUTE",
                params => {
                    ACTION => $action_name,
                    ERROR => scalar $error,
                    FIELDS => $invalid_fields
                }
            );
        }

        # If we have consecutive autorun actions the error bubbles up as the
        # workflow engine makes recursive calls, rethrow the first exception
        # instead of cascading them

        $e = OpenXPKI::Exception->caught();
        if ( (ref $e eq 'OpenXPKI::Exception') &&
            ( $e->message_code() eq 'I18N_OPENXPKI_SERVER_WORKFLOW_ERROR_ON_EXECUTE') ) {

            ##! 16: 'bubbled up error - rethrow'
            CTX('log')->application()->debug("Bubble up error from nested action");


            $e->rethrow;
        }

        # if we are here something IS wrong and we dont want to persist
        # whats in the transaction, so we do a rollback. This WILL drop any
        # traces of what happend in the meantime so make your workflow steps
        # as small and atomic as possible!
        CTX('dbi')->rollback();

        # this will update the workflow status data and commit internally
        $self->_proc_state_exception($error);

        # Look into the workflow definiton weather to autofail
        my $autofail = $self->_get_workflow_state()->{_actions}->{$action_name}->{autofail};
        if (defined $autofail && $autofail =~ /(yes|1)/i) {
            ##! 16: 'execute failed and has autofail set'
            $self->_fail($error);
        }

        # Something unexpected went wrong inside the action, throw exception
        # with original error attached
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_SERVER_WORKFLOW_ERROR_ON_EXECUTE",
            params => {
                ACTION => $action_name,
                ERROR => scalar $error,
                EXCEPTION => ref $error
            }
        );

    } else {
        #reset "count_try"
        $self->count_try(0);

        #determine proc_state: do we still hace actions to do?
        ##! 32: 'Workflow action ' . Dumper $self->_get_workflow_state()->{_actions}

        # Check if there are actions, get_current_actions is not working
        # here as it will hide non available actions based on acl or volatile state
        if ((ref $self->_get_workflow_state()->{_actions} eq 'HASH') && (keys %{$self->_get_workflow_state()->{_actions}}) ) {
            $self->_set_proc_state('manual');
        } else {
            $self->_set_proc_state('finished');
        }
    }

    return $state;

}

sub set_failed {

    my $self = shift;
    my $error = shift;
    my $reason = shift;

    $self->_fail($error, $reason);

    return $self;

}

# migrated from api - i have no idea what this is good for
sub reload_observer {

    ##! 1: 'start'
    my $self = shift;

    $self->delete_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $self->add_observer ('OpenXPKI::Server::Workflow::Observer::AddExecuteHistory');
    $self->delete_observer ('OpenXPKI::Server::Workflow::Observer::Log');
    $self->add_observer ('OpenXPKI::Server::Workflow::Observer::Log');

    return $self;
}

sub attrib {
    my ($self, $arg) = @_;
    ##! 1: 'start'

    # GETTER - return all attributes as HashRef
    return $self->{_attributes} if not $arg;

    # GETTER - return single value ($arg is scalar)
    return $self->{_attributes}->{$arg} if not ref $arg;

    OpenXPKI::Exception->throw(
        message => 'Wrong type of argument given to attrib()',
        params => { type => ref $arg }
    ) unless ref $arg eq 'HASH';

    # SETTER - $arg is a HashRef
    # Values of "undef" will be stored like that in $self->{_attributes},
    # so the persister knows that these shall be deleted from the storage.
    $self->{_attributes} = { %{$self->{_attributes}}, %{$arg} };
}


sub pause {

    # this method will be called from within the "pause"-Method of a OpenXPKI::Server::Workflow::Activity Object

    my $self = shift;
    my ($cause_description, $max_retries, $wakeup_at) = @_;

    #increase count try
    my $count_try = $self->count_try();
    $count_try||=0;
    $count_try++;


    ##! 16: sprintf('pause because of %s, max retries %d, retry interval %d, count try: %d ',$cause_description, $max_retries, $retry_interval, $wakeup_at)

    # maximum exceeded?
    if($count_try > $max_retries){
        #this exception will be catched from the workflow::execute_action method
        #proc_state and notifies/history-events will be handled there
        OpenXPKI::Exception->throw(
           message => 'I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_RETRIES_EXEEDED',
           params => { retries => $count_try, next_proc_state => 'retry_exceeded' }
       );
    }


    # This will catch invalid time formats
    my $dt_wakeup_at = DateTime->from_epoch( epoch => $wakeup_at );
    ##! 16: 'Wakeup at '. $dt_wakeup_at

    $self->wakeup_at( $dt_wakeup_at->epoch() );
    $self->count_try($count_try);
    $self->context->param( wf_pause_msg => $cause_description );
    $self->notify_observers( 'pause', $self->{_CURRENT_ACTION}, $cause_description );
    $self->add_history(
        Workflow::History->new(
            {
                action      => $self->{_CURRENT_ACTION},
                description => sprintf( 'PAUSED because of %s, count try %d, wakeup at %s', $cause_description ,$count_try, $dt_wakeup_at),
                state       => $self->state(),
                user        => CTX('session')->data->user,
            }
        )
    );
    $self->_set_proc_state('pause');#saves wf data

    CTX('log')->application()->info("Action ".$self->{_CURRENT_ACTION}." paused ($cause_description), wakeup $dt_wakeup_at");

}


=head2 set_reap_at_interval

Set the given argument as reap_at time in the database, calls the
persister if the workflow is already in run state. The interval must
be in relativedate format (@see OpenXPKI::DateTime). Auto-Persist
can be skipped by passing a true value as second argument.

=cut
sub set_reap_at_interval {
    my ($self, $interval, $bNoSave) = @_;

    ##! 16: sprintf('set retry interval to %s',$interval )

    my $reap_at = OpenXPKI::DateTime::get_validity(
            {
            VALIDITY => $interval,
            VALIDITYFORMAT => 'relativedate',
            },
        )->epoch();

    $self->reap_at($reap_at);
    # if the wf is already running, immediately save data to db:
    $self->_save() if (!$bNoSave && $self->is_running());
}

=head2 get_global_actions

Return an arrayref with the names of the global actions wakeup, resume, fail
that are available to the session user on this workflow.

=cut

sub get_global_actions {

    my $self = shift;

    # volatile or non initial workflow do not have any actions
    if ($self->id() < 1) {
         return [];
    }

    my $role = CTX('session')->data->role || 'Anonymous';

    my $acl = CTX('config')->get_hash([ 'workflow', 'def', $self->type(), 'acl', $role ] );

    my @possible_action;
    my $proc_state = $self->proc_state();
    if ($proc_state eq 'exception') {
        @possible_action = ('resume','fail');

    } elsif ($proc_state eq 'pause') {
        @possible_action = ('wakeup','fail');

    } elsif ($proc_state eq 'retry_exceeded') {
        @possible_action = ('wakeup','fail');

    } elsif ($proc_state ne 'finished') {
        @possible_action = ('fail');

    }

    # always possible
    push @possible_action, ('history', 'techlog', 'context');

    my @allowed;
    foreach my $action (@possible_action) {
        if ($acl->{$action}) {
            push @allowed, $action;
        }
    }

    return \@allowed;

}


sub _handle_proc_state{
    my ( $self, $action_name ) = @_;

    ##! 16: sprintf('action %s, handle_proc_state %s',$action_name,$self->proc_state)

    my $action_needed = $known_proc_states{$self->proc_state}->{action};
    if(!$action_needed){

        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_WORKFLOW_UNKNOWN_PROC_STATE",
                params  => {DESCRIPTION => sprintf('unkown proc-state: %s',$self->proc_state)}
            );

    }
    if($action_needed eq 'none'){
        ##! 16: 'no action needed for proc_state '. $self->proc_state
        return;
    }

    #we COULD use symbolic references to method-calls here, but - for the moment - we handle it explizit:
    if($action_needed eq '_wake_up'){
        ##! 1: 'paused, call wakeup '
         CTX('log')->application()->debug("Action $action_name waking up");

        $self->_wake_up($action_name);
    }elsif($action_needed eq '_resume'){
        ##! 1: 'call _resume '
        CTX('log')->application()->debug("Action $action_name resume");

        $self->_resume($action_name);
    }elsif($action_needed eq '_runtime_exception'){
        ##! 1: 'call _runtime_exception '
        CTX('log')->application()->debug("Action $action_name runtime exception");

        $self->_runtime_exception($action_name);
    }else{
        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_WORKFLOW_UNKNOWN_PROC_STATE_ACTION",
                params  => {DESCRIPTION => sprintf('unkown action "%s" for proc-state: %s',$action_needed, $self->proc_state)}
            );
    }

}

sub _wake_up {
    my ( $self, $action_name ) = @_;
    eval {
        my $action = $self->_get_action($action_name);
        $self->notify_observers( 'wakeup', $action_name );
        $self->add_history(
            Workflow::History->new(
                {
                    action      => $action_name,
                    description => 'WAKEUP',
                    state       => $self->state(),
                    user        => CTX('session')->data->user,
                }
            )
        );
        $self->_set_proc_state('wakeup');#saves wf data
        $self->context->param( wf_pause_msg => '' );
        $action->wake_up($self);
    };
    if (my $eval_err = $EVAL_ERROR) {
        $self->_proc_state_exception( $eval_err );

        # Don't use 'workflow_error' here since $eval_err should already
        # be a Workflow::Exception object or subclass
        croak $eval_err;
    }
}

sub _resume {
    my ( $self, $action_name ) = @_;

    eval {
        my $action = $self->_get_action($action_name);
        my $old_state = $self->proc_state();
        $self->notify_observers( 'resume', $action_name );
        $self->add_history(
            Workflow::History->new(
                {
                    action      => $action_name,
                    description => 'RESUME',
                    state       => $self->state(),
                    user        => CTX('session')->data->user,
                }
            )
        );
        $self->context->param( wf_exception => undef ) if $self->context->param('wf_exception');
        $self->_set_proc_state('resume');#saves wf data
        $action->resume($self,$old_state);

    };
    if (my $eval_err = $EVAL_ERROR) {
        $self->_proc_state_exception(  $eval_err );

        # Don't use 'workflow_error' here since $eval_err should already
        # be a Workflow::Exception object or subclass
        croak $eval_err;
    }

}

sub _runtime_exception {
    my ( $self, $action_name ) = @_;

    eval {
        my $action = $self->_get_action($action_name);

        $action->runtime_exception($self);

        OpenXPKI::Exception->throw (
                message => "I18N_OPENXPKI_WORKFLOW_RUNTIME_EXCEPTION",
                params  => {DESCRIPTION => sprintf('Action "%s" was called on Proc-State "%s".',$action_name,$self->proc_state() )}
            );

    };
    if (my $eval_err = $EVAL_ERROR) {
        $self->_proc_state_exception( $eval_err );

        # Don't use 'workflow_error' here since $eval_err should already
        # be a Workflow::Exception object or subclass
        croak $eval_err;
    }

}



sub _set_proc_state{
    my $self = shift;
    my $proc_state = shift;

    ##! 20: sprintf('_set_proc_state from %s to %s, Wfl State: %s', $self->proc_state(), $proc_state, $self->state());

    if(!$known_proc_states{$proc_state}){
        OpenXPKI::Exception->throw (
            message => "I18N_OPENXPKI_WORKFLOW_UNKNOWN_PROC_STATE",
            params  => {DESCRIPTION => sprintf('unkown proc-state: %s',$proc_state)}
        );
    }

    $self->proc_state($proc_state);
    $self->_save();

}

sub _proc_state_exception {
    my $self      = shift;
    my $error = shift;

    my ($error_code, $error_msg,  $next_proc_state);

    if(blessed( $error ) && $error->isa("OpenXPKI::Exception")){
        $error_msg = $error->full_message();
        $error_code = $error->message_code();
        my $params = $error->params();
        $next_proc_state = (defined $params->{__next_proc_state__})?$params->{__next_proc_state__}:'';
        ##! 128: sprintf('next proc-state defined in exception: %s',$next_proc_state)
        ##! 228: Dumper($params)
    }else{
        $error_code = $error_msg = $error;
    }

    # next_proc_state defaults to "exception"
    $next_proc_state = 'exception' unless $next_proc_state && $known_proc_states{$next_proc_state};

    #we are already in exception context, so we dont need another exception:
    eval{
        $self->context->param( wf_exception => $error_code );
        $self->_set_proc_state($next_proc_state);
        $self->notify_observers( $next_proc_state, $self->{_CURRENT_ACTION}, $error );
        $self->add_history(
            Workflow::History->new(
                {
                    action      => $self->{_CURRENT_ACTION},
                    description => sprintf( 'EXCEPTION: %s ', $error_msg ),
                    user        => CTX('session')->data->user,
                }
            )
        );
        $self->_save();

    };

}

sub _fail {

    my $self = shift;
    my $error = shift;
    my $reason = shift || 'autofail';

    eval{
        $self->state('FAILURE');
        $self->_set_proc_state('finished');
        $self->notify_observers( 'fail', $self->state, $self->{_CURRENT_ACTION}, $error);
        $self->add_history(
            Workflow::History->new(
                {
                    action      => $self->{_CURRENT_ACTION},
                    description => $reason,
                    user        => CTX('session')->data->user,
                }
            )
        );
        $self->_save();
    };

    if ($reason eq 'autofail') {
        CTX('log')->application()->error("Auto-Fail workflow ".$self->id." after action ".$self->{_CURRENT_ACTION}." with error " . $error);

    } else {
        CTX('log')->application()->info("Forced Fail for workflow ".$self->id." after action ".$self->{_CURRENT_ACTION});

    }

}

sub is_running(){
    my $self = shift;
    return ( $self->proc_state eq 'running');
}

sub _has_paused {
    my $self = shift;
    return ( $self->proc_state eq 'pause' );
}

sub _get_next_state {
    my ( $self, $action_name, $action_return ) = @_;

    if ( $self->_has_paused() ) {
        my $state = Workflow->NO_CHANGE_VALUE;
        my $msg = sprintf( 'Workflow %d, Action %s has paused, return %s', $self->id, $action_name, $state );
        ##! 16: $msg

        return $state;
    }

    return $self->SUPER::_get_next_state( $action_name, $action_return );
}

sub _save {
    my $self = shift;
    ##! 20: 'save workflow!'

    # do not save if we are in the startup phase of a workflow
    # Some niffy tasks create broken workflows for validating
    # parameters and we will get tons of init/exception entries
    my $proc_state = $self->proc_state;

    if ($self->state() eq 'INITIAL' &&
        ($proc_state eq 'init' || $proc_state eq 'running' || $proc_state eq 'exception' )) {
        CTX('log')->workflow()->debug("Workflow save requested during startup - wont save! ($proc_state)");
        ##! 20: sprintf 'dont save as we are in startup phase (proc state %s) !', $proc_state ;
        return;
    }

    $self->_factory()->save_workflow($self);

    # If using a DBI persister with no autocommit, commit here.
    $self->_factory()->_commit_transaction($self);
}

# Override from Class::Accessor so only certain callers can set
# properties

sub set {
    my ( $self, $prop, $value ) = @_;
    my $calling_pkg = ( caller 1 )[0];
    unless ( ( $calling_pkg =~ /^OpenXPKI::Server::Workflow/ ) || ( $calling_pkg =~ /^Workflow/ ) ) {
        carp "Tried to set from: ", join ', ', caller 1;
        workflow_error "Don't try to use my private setters from '$calling_pkg'!";
    }
    $self->{$prop} = $value;
}

sub factory {
    my $self = shift;
    return $self->_factory();
}


1;
__END__

=head1 Name

OpenXPKI::Server::Workflow

=head1 Description

This is the OpenXPKI specific subclass of Workflow.

Purpose: overwrite the Method "execute_action" of the baseclass to implement the feature of "pauseing / wake-up / resuming" workflows

The workflow-table is expanded with 4 new persistent fields (see database schema)

    workflow_proc_state
    workflow_wakeup_at
    workflow_count_try
    workflow_reap_at

Essential field is C<workflow_proc_state>, internally "proc_state". All known and possible proc_states and their follow-up actions are defined in %known_proc_states.
"running" will be set, before SUPER::execute_action/Activity::run is called.
After execution of one or more Activities, either "manual" (waiting for interaction)  or "finished" will be set.
If an exception occurs, the proc state "exception" is set. Also the message code (not translation) will be saved in WF context (key "wf_exception")
The two states "pause" and "retry_exceeded" concern the  "pause" feature.


=head1 Usage documentation and guidelines

Please refer to the documentation of Workflow Modul for basic usage


=head2 new

Constructor. Takes the original Workflow-Object as first argument and take all his properties - after that the object IS the original workflow.

=head2 execute_action

wrapper around super::execute_action. does some initialisation before, checks the current proc_state, trigger the "resume"/"wake_up" - hooks,
sets the "reap_at"-timestamp, sets the proc state to "running".

after super::execute_action() the special "OpenXPKI::Server::Workflow::Pause"-exception will be handled and some finalisation takes place.

=head2 pause

should not be called manually/explicitly. Activities should always use $self->pause($msg) (= OpenXPKI::Server::Workflow::Activity::pause()).
calculates and stores the "count_try" and "wake_up_at" information. if "max_count:_try" is exceeded, an special exception
I18N_OPENXPKI_SERVER_WORKFLOW_ACTIVITY_RETRIES_EXEEDED will be thrown.
The given cause of pausing will be stored in context key "wf_pause_msg". history etries are made, observers notified.
Note that pause requires an epoch value for $wakeup_at and NOT a relative date!

=head2 _handle_proc_state

checks the current proc state and determines the follwo up action (e.g. "pause"->"wake_up")

=head2 _wake_up

wrapper and try/catch around Activity::wake_up(). makes history entries and notifies observers.
sets the proc_state to "wakeup".

=head2 _resume

wrapper and try/catch around Activity::resume(). makes history entries and notifies observers.
sets the proc_state to "wakeup".


=head2 _runtime_exception

after calling Activity::runtime_exception() throws I18N_OPENXPKI_WORKFLOW_RUNTIME_EXCEPTION

=head2 _set_proc_state($state)

stores the proc_state in  the class field "proc_state" and calls $self->_save();

=head2 _proc_state_exception

is called if an exception occurs during execute_action. the code of the exception (not the translation) is stored in context key "wf_exception".
observers are notified, history written. the proc_state is set to "exception",
if not otherwise specified (via param "next_proc_state" given to Exception::throw(), see pause() for details. Caveat: in any case the proc_state must be specified in %known_proc_states).

=head2 _has_paused

true, if the workflow has paused (i.e. the proc state is "pause")

=head2 is_running

true, if the workflow is running(i.e. the proc state is "running")

=head2 _get_next_state

overwritten from parent Workflow class. handles the special case "pause", otherwise it calls super::_get_next_state()

=head2 persist_context

Internal flag to control the behaviour of the context/attribute persister:

  0: do not persist anything
  1: persist only the internal flags (context starting with wf_)
  2: persist all updated values (context and attributes)

=head2 factory

return a ref to the workflows factory

=head2 _save

calls $self->_factory()->save_workflow($self);

=head2 set

overwritten from parent Workflow class. adds the OpenXPKI-package to the "allowed" packages, which CAN set internal properties.

=head3 Workflow context

See documentation for
OpenXPKI::Server::Workflow::Persister::DBI::update_workflow()
for limitations that exist for data stored in Workflow Contexts.

=head2 Activities

=head3 Creating new activities

For creating a new Workflow activity it is advisable to start with the
activity template available in OpenXPKI::Server::Workflow::Activity::Skeleton.

=head3 Authorization and access control

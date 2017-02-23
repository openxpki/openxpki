package OpenXPKI::Server::Watchdog::WorkflowInstance;

=head1 NAME

OpenXPKI::Server::Watchdog::WorkflowInstance - The workflow instance handler

=head1 DESCRIPTION

This class is responsible for waking up paused workflows. Its L</run> method is
called from L<OpenXPKI::Server::Watchdog>. Immediately a child process will be
created via C<fork()> and L</__wake_up_workflow> is called within the child.

L</__wake_up_workflow> imports the given serialized session infos into the
current (watchdog's) session, so that the workflow is executed within its
original environment.

The last performed action is retrieved from workflow history, then executed
again (via L<OpenXPKI::Server::API::Workflow>).

=cut

use Moose;

use English;
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::DateTime;
use OpenXPKI::MooseParams;

use Data::Dumper;

################################################################################
# Attributes
#

# Constructor arguments

has 'workflow_id' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'workflow_type' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'workflow_session' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

has 'pki_realm' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

################################################################################
# Methods
#

sub run {
    my $self = shift;

    my $pid;
    my $redo_count = 0;

    $SIG{'CHLD'} = sub { wait; };
    while ( !defined $pid && $redo_count < 5 ) {
        ##! 16: 'trying to fork'
        $pid = fork();
        ##! 16: 'pid: ' . $pid
        if ( !defined $pid ) {
            if ( $!{EAGAIN} ) {

                # recoverable fork error
                sleep 2;
                $redo_count++;
            } else {

                # other fork error
                OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_EXECUTION_FAILED', );
            }
        }
    }

    OpenXPKI::Exception->throw( message => 'I18N_OPENXPKI_SERVER_WATCHDOG_FORK_WORKFLOW_EXECUTION_FAILED' )
        unless( defined $pid );

    # Reconnect the db handles
    CTX('dbi_log')->new_dbh();
    CTX('dbi_workflow')->new_dbh();
    CTX('dbi_backend')->new_dbh();
    CTX('dbi_log')->connect();
    CTX('dbi_workflow')->connect();
    CTX('dbi_backend')->connect();

    if ( $pid != 0 ) {
    	##! 16: ' Workflow instance succesfully forked - I am the watchdog'
    	# parent here - noop
    	return;
    }

    #
    # Child process from here on
    #

    ##! 16: ' Workflow instance succesfully forked - I am the workflow'
    # We need to unset the child reaper (waitpid) as the universal waitpid
    # causes problems with Proc::SafeExec
    $SIG{CHLD} = 'DEFAULT';

    # Re-seed Perl random number generator
    srand(time ^ $PROCESS_ID);

    # append fork info to process name
    $0 = sprintf('openxpkid (%s) workflow: id %d', (CTX('config')->get('system.server.name') || 'main'), $self->workflow_id);

    # the wf instance child processs should ALWAYS exit properly and not
    # let its exceptions bubble up to Watchdog
    eval { $self->__wake_up_workflow; };
    my $error_msg;
    if ( my $exc = OpenXPKI::Exception->caught() ) {
        $exc->show_trace(1);
        $error_msg = "OpenXPKI::Server::Watchdog::WorkflowInstance: Exception caught while executing _wake_up_workflow: $exc";
    }
    elsif ($EVAL_ERROR) {
        $error_msg = "OpenXPKI::Server::Watchdog::WorkflowInstance: Fatal error while executing _wake_up_workflow:" . $EVAL_ERROR;
    }
    if ($error_msg) {
        CTX('log')->log(
            MESSAGE  => $error_msg,
            PRIORITY => "fatal",
            FACILITY => "workflow"
        );
    }
    # ALWAYS exit child process
    exit;
}


=head1 __wake_up_workflow

Re-instantiates the workflow and re-runs the paused activity.

=cut

sub __wake_up_workflow {
    my $self = shift;

    $self->__check_session();

    CTX('session')->set_pki_realm($self->pki_realm);
    CTX('session')->import_serialized_info($self->workflow_session);

    my $wf_info = CTX('api')->wakeup_workflow({
        WORKFLOW => $self->workflow_type,
        ID => $self->workflow_id
    });
    ##! 16: 'wf info after wake up: ' .Dumper( $wf_info )
}

=head2 __check_session

Returns the session from the context (if existing) or creates a new one.

=cut

sub __check_session {
    my $self = shift;

    my $session;
    eval { $session = CTX('session') };
    return $session if $session;

    ##! 4: "create new session"
    $session = OpenXPKI::Server::Session->new({
        DIRECTORY => CTX('config')->get("system.server.session.directory"),
        LIFETIME  => CTX('config')->get("system.server.session.lifetime"),
    });
    OpenXPKI::Server::Context::setcontext({'session' => $session});
    ##! 4: sprintf(" session %s created" , $session->get_id())
    return $session;
}

1;

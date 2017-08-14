package OpenXPKI::Daemonize;
use Moose;

=head1 Name

OpenXPKI::Daemonize - Helper functions to cleanly fork background processes

=cut

# Core modules
use English;

# CPAN modules
use POSIX qw(:signal_h setuid setgid);

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;

has max_fork_redo => (
    is => 'rw',
    isa => 'Int',
    default => 5,
);

has sighup_handler => (
    is => 'rw',
    isa => 'CodeRef',
);

has sigterm_handler => (
    is => 'rw',
    isa => 'CodeRef',
);

has uid => (
    is => 'rw',
    isa => 'Int',
);

has gid => (
    is => 'rw',
    isa => 'Int',
);

has old_sig_set => (
    is => 'rw',
    isa => 'POSIX::SigSet',
    init_arg => undef,
);

=head1 METHODS

=head2 fork_child

Tries to fork a child process.

Return value depends on who returns: parent will get the child PID and child
will get 0.

An exception will be thrown if the fork fails.

B<Note on STDIN, STDOUT, STDERR>

All IO handles will be connected to I</dev/null> with one exception: if C<STDERR>
was already redirected to a file (and is not a terminal) then it is left untouched.
This is to make sure error messages still go to the desired log files.

B<Note on SIGCHLD>

For the parent process we set C<$SIG{CHLD} = "IGNORE"> to prevent zombie child
processes.

But C<IGNORE> can lead to problems with system calls e.g. via L<Proc::SafeExec>
or L<system>, see
L<the Perl CookBook|https://docstore.mik.ua/orelly/perl/cookbook/ch16_20.htm>
for details.

Thus in the child process we set C<$SIG{CHLD} = "DEFAULT"> to prevent these
problems.

But in the parent process after forking you should manually set
C<$SIG{CHLD} = "DEFAULT"> if you want to do system calls.

=cut
sub fork_child {
    my ($self) = @_;

    $SIG{CHLD} = 'IGNORE'; # IGNORE means: child zombies are auto-removed from process table

    my $pid = $self->_try_fork($self->max_fork_redo);

    # parent process: return on successful fork
    if ($pid > 0) { return $pid }

    #
    # child process
    #

    # Reset handler for SIGCHLD:
    # IGNORE could prevent Proc::SafeExec or system() from working correctly
    # (see https://docstore.mik.ua/orelly/perl/cookbook/ch16_20.htm)
    $SIG{CHLD} = 'DEFAULT';
    $SIG{HUP}  = $self->sighup_handler  if $self->sighup_handler;
    $SIG{TERM} = $self->sigterm_handler if $self->sigterm_handler;

    if ($self->gid) {
        setgid($self->gid);
    }
    if ($self->uid) {
        setuid($self->uid);
        $ENV{USER} = getpwuid($self->uid);
        $ENV{HOME} = ((getpwuid($self->uid))[7]);
    }

    umask 0;
    chdir '/';
    open STDIN,  '<',  '/dev/null';
    open STDOUT, '>',  '/dev/null';
    open STDERR, '>>', '/dev/null' if (-t STDERR); # only touch STDERR if it's not already redirected to a file

    # Re-seed Perl random number generator
    srand(time ^ $PROCESS_ID);

    return $pid;
}

# "The most paranoid of programmers block signals for a fork to prevent a
# signal handler in the child process being called before Perl can update
# the child's $$ variable, its process id."
# (https://docstore.mik.ua/orelly/perl/cookbook/ch16_21.htm)
sub _block_sigint {
    my ($self) = @_;
    my $sigint = POSIX::SigSet->new(SIGINT);
    sigprocmask(SIG_BLOCK, $sigint, $self->old_sig_set)
        or OpenXPKI::Exception->throw(
            message => 'Unable to block SIGINT before fork()',
            log => { priority => 'fatal', facility => 'system' }
        );
}

sub _unblock_sigint {
    my ($self) = @_;
    sigprocmask(SIG_SETMASK, $self->old_sig_set)
        or OpenXPKI::Exception->throw(
            message => 'Unable to reset old signals after fork()',
            log => { priority => 'fatal', facility => 'system' }
        );
}

sub _try_fork {
    my ($self, $max_tries) = @_;

    for (my $i = 0; $i < $max_tries; $i++) {
        $self->_block_sigint;
        my $pid = fork;
        $self->_unblock_sigint;
        # parent or child: successful fork
        if (defined $pid) { return $pid }

        # parent: unsuccessful fork

        # EAGAIN - fork cannot allocate sufficient memory to copy the parent's
        #          page tables and allocate a task structure for the child.
        # ENOMEM - fork failed to allocate the necessary kernel structures
        #          because memory is tight.
        if ($! != POSIX::EAGAIN() and $! != POSIX::ENOMEM()) {
            OpenXPKI::Exception->throw(
                message => 'fork() failed with an unrecoverable error',
                params => { error => $! },
                log => { priority => 'fatal', facility => 'system' }
            );
        }
        sleep 2;
    }

    OpenXPKI::Exception->throw(
        message => 'fork() failed due to insufficient memory, tried $max_tries times',
        log => { priority => 'fatal', facility => 'system' }
    );
}

__PACKAGE__->meta->make_immutable;

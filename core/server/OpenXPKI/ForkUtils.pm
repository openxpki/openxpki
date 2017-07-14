package OpenXPKI::ForkUtils;
use Moose;

=head1 Name

OpenXPKI::ForkUtils - Helper functions to cleanly fork background processes

=cut

# Core modules
use English;

# CPAN modules
use POSIX;

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::MooseParams;

has sigint_set => (
    is => 'rw',
    isa => 'POSIX::SigSet',
    lazy => 1,
    init_arg => undef,
    default => sub { POSIX::SigSet->new(SIGINT) },
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
    my ($self, %params) = named_args(\@_,   # OpenXPKI::MooseParams
        max_fork_redo   => { isa => 'Int', default => 5 },
        sighup_handler  => { isa => 'CodeRef', optional => 1 },
        sigterm_handler => { isa => 'CodeRef', optional => 1 },
        stderr          => { isa => 'Str', default => '/dev/null' },
    );

    $SIG{CHLD} = 'IGNORE'; # IGNORE means: child zombies are auto-removed from process table

    my $pid = $self->_try_fork($params{max_fork_redo});

    # parent process: return on successful fork
    if ($pid > 0) { return $pid }

    #
    # child process
    #

    # Reset handler for SIGCHLD:
    # IGNORE could prevent Proc::SafeExec or system() from working correctly
    # (see https://docstore.mik.ua/orelly/perl/cookbook/ch16_20.htm)
    $SIG{CHLD} = 'DEFAULT';
    $SIG{HUP}  = $params{sighup_handler}  if $params{sighup_handler};
    $SIG{TERM} = $params{sigterm_handler} if $params{sigterm_handler};

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
    sigprocmask(SIG_BLOCK, $self->sigint_set)
        or OpenXPKI::Exception->throw(
            message => 'Unable to block SIGINT before fork()',
            log => { priority => 'fatal', facility => 'system' }
        );
}
sub _unblock_sigint {
    my ($self) = @_;
    sigprocmask(SIG_UNBLOCK, $self->sigint_set)
        or OpenXPKI::Exception->throw(
            message => 'Unable to unblock SIGINT after fork()',
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

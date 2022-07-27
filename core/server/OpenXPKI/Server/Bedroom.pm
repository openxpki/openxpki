package OpenXPKI::Server::Bedroom;
use Moose;

=head1 NAME

OpenXPKI::Server::Bedroom - Helper module to... err... make child processes

=head1 DESCRIPTION

=head2 Note on SIGCHLD

The requirements for a proper C<SIGCHLD> handling are:

=over

=item * avoid zombie processes of our forked children by calling C<waitpid()>
on them,

=item * allow follow up code to evaluate the status of e.g. C<sytem()> calls
or doing own C<waitpid()> on children not forked by C<OpenXPKI::Server::Bedroom>,

=item * avoid interfering with L<Net::Server>'s C<SIGCHLD> handler,

=item * keep the C<OpenXPKI::Server::Bedroom> instance that contains the C<SIGCHLD>
handler alive as long as there are child processes. Destroying the instance
too early could lead to errors: without resetting C<SIGCHLD> handler to
C<'IGNORE'> a finished child process would raise the error
I<"Signal SIGCHLD received, but no signal handler set">. When set to C<'IGNORE'>
e.g. a following C<system()> call from code higher up the hierarchy would fail.

=back

The most compatible way to handle C<SIGCHLD> is to set it to C<'DEFAULT'>,
letting Perl handle it. This way commands like C<system()> will work properly.

But for the C<OpenXPKI::Server::Bedroom> parent process to be able to reap its child
processes we need a custom C<SIGCHLD> handler to call C<waitpid()> on them.
So in our custom handler we keep track of the PIDs of our own forked children
and only reap those. Other children (e.g. forked via C<system()>) are left
untouched.

Thus there are two usage modes:

=over

=item 1. Default (C<keep_parent_sigchld =E<gt> 0>):

Parent: install custom C<SIGCHLD> handler (NOT compatible with C<Net::Server>
parent process, reaps children forked by us, C<system()> compatible)

Child: inherit parent's custom handler

=item 2. C<keep_parent_sigchld =E<gt> 1> (for use in C<Net::Server> parent
process):

Parent: do not touch C<SIGCHLD> handler (to keep C<Net::Server>'s handler,
reaps children forked by us via existing handler, NOT C<system()> compatible)

Child: set C<$SIG{'CHLD'} = 'DEFAULT'>.

=back

If this object is destroyed while the C<$SIG{'CHLD'}> still refers to our
handler then children exiting later on will raise the internal Perl error
I<"Signal SIGCHLD received, but no signal handler set.">

That is why in L</DEMOLISH> we explicitely hand over child reaping to the
operating system. But this also means after this the process will not be
able to call C<system()> and the like anymore. So a better solution is to
keep this object alive as long as possible, ideally until C<OpenXPKI::Server>
shuts down.

Also see L<https://github.com/Perl/perl5/issues/17662>, might be related.

Also see L<https://perldoc.perl.org/perlipc#Signals>.

=cut

# Core modules
use English;

# CPAN modules
use POSIX ();

# Project modules
use OpenXPKI::Debug;
use OpenXPKI::Exception;
use OpenXPKI::MooseParams;

#
has old_sig_set => (
    is => 'rw',
    isa => 'POSIX::SigSet',
    init_arg => undef,
);

# Store PIDs of forked child processes.
# The list is purged after fork() so it doesn't grow with every child process.
# By using a package variable this acts like a Singleton, so a new instance
# of OpenXPKI::Server::Bedroom won't delete collected child PIDs of previous instance.
my $current_pid = $$;
my %child_pids_by_parent = ();

sub _get_child_pids {
    if ($current_pid != $$) { $current_pid = $$; %child_pids_by_parent = () } # reset PID list after fork()
    return keys %child_pids_by_parent;
}

sub _add_child_pid {
    my $pid = shift;
    if ($current_pid != $$) { $current_pid = $$; %child_pids_by_parent = () } # reset PID list after fork()
    $child_pids_by_parent{$pid} = 1;
}

sub _remove_child_pid {
    my $pid = shift;
    delete $child_pids_by_parent{$pid};
}

=head1 METHODS

=head2 new_child

Tries to fork a child process.

Return value depends on who returns: parent will get the child PID and child
will get 0.

An exception will be thrown if the fork fails.

B<Note on STDIN, STDOUT, STDERR>

All IO handles will be connected to I</dev/null> with one exception: if C<STDERR>
was already redirected to a file (and is not a terminal) then it is left untouched.
This is to make sure error messages still go to the desired log files.

B<Parameters>

=over

=item * C<max_fork_redo> I<Int> - optional: max. retries in case forking fails. Default: 5.

=item * C<sighup_handler> I<CodeRef> - optional: handler for C<SIGHUP> signals.

=item * C<sigterm_handler> I<CodeRef> - optional: handler for C<SIGTERM> signals.

=item * C<uid> I<Int> - optional: user ID to set for the newly forked child process. Default: do not change ID.

=item * C<gid> I<Int> - optional: group ID to set for the newly forked child process. Default: do not change ID.

=item * C<keep_parent_sigchld> I<Bool> - optional: C<1> = parent: keep currently installed C<SIGCHLD> handler,
child: set C<SIGCHLD> to C<default>. Default: 0

=back

=cut

sub new_child {
    my ($self, %args) = named_args(\@_,   # OpenXPKI::MooseParams
        max_fork_redo => { isa => 'Int', optional => 1,default => 5 },
        sighup_handler => { isa => 'CodeRef', optional => 1 },
        sigterm_handler => { isa => 'CodeRef', optional => 1 },
        uid => { isa => 'Int', optional => 1 },
        gid => { isa => 'Int', optional => 1 },
        keep_parent_sigchld => { isa => 'Bool', optional => 1, default => 0 },
    );

    ##! 1: 'start - $SIG{"CHLD"}: ' . ($SIG{'CHLD'}//'<undef>')

    # Reap child processes while allowing e.g. system() to work properly.
    $SIG{'CHLD'} = \&_catch_them_all if not $args{keep_parent_sigchld};

    ##! 1: 'start - $SIG{"CHLD"}: ' . ($SIG{'CHLD'}//'<undef>')

    my $pid = $self->_try_fork($args{max_fork_redo});

    # parent process: return on successful fork
    if ($pid > 0) {
        ##! 1: "parent: child PID = $pid"
        _add_child_pid($pid);
        return $pid;
    }

    #
    # child process
    #
    ##! 1: 'child: $SIG{"CHLD"}: ' . ($SIG{'CHLD'}//'<undef>')

    # allow execution of system() etc. if parent did NOT set our special handler for them and us
    $SIG{'CHLD'} = 'default' if $args{keep_parent_sigchld};
    $SIG{'HUP'}  = $args{sighup_handler}  if $args{sighup_handler};
    $SIG{'TERM'} = $args{sigterm_handler} if $args{sigterm_handler};

    if ($args{gid}) {
        POSIX::setgid($args{gid});
    }
    if ($args{uid}) {
        POSIX::setuid($args{uid});
        $ENV{USER} = getpwuid($args{uid});
        $ENV{HOME} = ((getpwuid($args{uid}))[7]);
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

# SIGCHLD handler
sub _catch_them_all {
    # Don't overwrite current error and status codes outside this signal handler
    local ($!, $?);

    # Only try to reap the children we forked ourselves
    my @kids = _get_child_pids;

    # Clean up any child process that became a zombie via non-blocking waitpid().
    # By explicitely NOT calling waitpid(-1, ...) we avoid interfering with
    # calls to system() and others.
    # (see https://perldoc.perl.org/functions/waitpid)
    for my $pid (@kids) {
        my $code = waitpid($pid, POSIX::WNOHANG);
        # SIGCHLD will also be sent if a child process was only stopped,
        # not terminated. So we check $? aka "native status" of waitpid()
        # via POSIX::WIFEXITED.
        if ($code > 0 && POSIX::WIFEXITED($?)) {
            _remove_child_pid($pid);
        }
    }

    # SysV compatibility: reinstall signal handler
    $SIG{'CHLD'} = \&_catch_them_all;
}

=head2 DEMOLISH

Hand C<SIGCHLD> processing over to operating system via
C<$SIG{'CHLD'} = 'IGNORE'>, see L</Note on SIGCHLD>.

=cut
sub DEMOLISH {
    my $self = shift;
    my $is_global_destruction = shift;
    my $is_our_handler = ($SIG{'CHLD'} // '') eq \&_catch_them_all;

    ##! 1: 'start - global destruction: ' . ($is_global_destruction ? 'yes' : 'no') . ', $SIG{"CHLD"}: ' . ($SIG{'CHLD'}//'<undef>') . ' - our handler: ' . ($is_our_handler ? 'yes' : 'no')

    # Prevent "Signal SIGCHLD received, but no signal handler set."
    $SIG{'CHLD'} = 'IGNORE';

    # Warn of consequences if this is not Perls global destruction
    if ($is_our_handler and not $is_global_destruction) {
        warn "WARNING: OpenXPKI::Server::Bedroom is about to be destroyed but \$SIG{'CHLD'} still referred to our handler. It was set to 'IGNORE' instead.";
    }
}

# "The most paranoid of programmers block signals for a fork to prevent a
# signal handler in the child process being called before Perl can update
# the child's $$ variable, its process id."
# (https://docstore.mik.ua/orelly/perl/cookbook/ch16_21.htm)
sub _block_sigint {
    my ($self) = @_;
    my $sigint = POSIX::SigSet->new(POSIX::SIGINT());
    POSIX::sigprocmask(POSIX::SIG_BLOCK(), $sigint, $self->old_sig_set)
        or OpenXPKI::Exception->throw(
            message => 'Unable to block SIGINT before fork()',
            log => { priority => 'fatal', facility => 'system' }
        );
}

sub _unblock_sigint {
    my ($self) = @_;
    POSIX::sigprocmask(POSIX::SIG_SETMASK(), $self->old_sig_set)
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

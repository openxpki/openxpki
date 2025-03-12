package OpenXPKI::Control::Role;
use OpenXPKI -role;

=head1 OpenXPKI::Control::Role

Role that must be consumed by backend classes that provide an C<openxpkictl>
scope:

=over

=item * L<OpenXPKI::Control::Client>

=item * L<OpenXPKI::Control::Server>

=item * L<OpenXPKI::Control::Terminal>

=back

=head1 REQUIRED METHODS

=head2 getopt_params

Passed parameter: C<$command> I<Str>.

Must return a list of parameters to pass to L<Getopt::Long/GetOptions>.

=cut
requires 'getopt_params';

=head2 cmd_start

=head2 cmd_stop

=head2 cmd_reload

Should reload the configuration without restart if possible. Otherwise it should
just call L</cmd_restart>.

=head2 cmd_restart

=head2 cmd_status

Should return the value C<0> if the processes are running, a value C<E<gt> 0>
otherwise.

=cut
requires 'cmd_start';
requires 'cmd_stop';
requires 'cmd_reload';
requires 'cmd_restart';
requires 'cmd_status';

# CPAN modules
use Proc::ProcessTable;


has config_path => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_config_path',
);

has args => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

has global_opts => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

has opts => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

=head1 METHODS

=head2 stop_process

Stop all subprocesses of the given process (i.e. processes belonging to the same
process group) and finally the parent process itself.

B<Named parameters>

=over

=item * C<name> I<Str> - process description (for output messages)

=item * C<pid> I<Int> - process ID (may be C<undef> so no checks are neccessary in advance)

=item * C<silent> I<Bool> - set to C<1> to suppress messages

=back

=cut
signature_for stop_process => (
    method => 1,
    named => [
        name => 'Str',
        pid => 'Int|Undef',
        silent => 'Bool', { default => 0 },
    ],
);
sub stop_process ($self, $arg) {
    if (not defined $arg->pid) {
        printf "%s is not running\n", $arg->name unless $arg->silent;
        return 0;
    }
    if (kill(0, $arg->pid) == 0) {
        printf "%s is not running under PID %s\n", $arg->name, $arg->pid unless $arg->silent;
        return 0;
    }

    my $process_group = getpgrp($arg->pid);

    say 'Stopping '.$arg->name unless $arg->silent;

    # get all PIDs which belong to the current process group
    my $pt = Proc::ProcessTable->new;
    my @child_pids =
        grep { $_ != $arg->pid and getpgrp($_) == $process_group }
        map { $_->pid }
        @{$pt->table};

    $self->__stop_em(label => 'subprocesses', pids => \@child_pids, silent => $arg->silent);
    $self->__stop_em(label => 'main process', pids => [ $arg->pid ], silent => $arg->silent);

    my @pids = $self->__filter_alive($arg->pid, @child_pids);
   if (scalar @pids <= 0) {
        say "DONE." unless $arg->silent;
        return 0;
    } else {
        say "FAILED." unless $arg->silent;
        warn "Could not terminate: ".join(" ", @pids).".\n";
        return 2;
    }
}

signature_for __stop_em => (
    method => 1,
    named => [
        pids => 'ArrayRef',
        label => 'Str',
        silent => 'Bool', { default => 0 },
    ],
);
sub __stop_em ($self, $arg) {
    my @pids = $arg->pids->@*;
    my $total = scalar @pids;

    # try to send them SIGTERM
    my $attempts = 10;
    while ($attempts-- > 0) {
        @pids = $self->__filter_alive(@pids);
        my $count = scalar @pids;
        last if ($count <= 0);
        printf("Stopping %s gracefully (SIGTERM)%s\n", $arg->label, $total > 1 ? ", $count remaining..." : '')
            unless $arg->silent;
        kill(15, $_) for @pids;
        sleep 1;
    }

    # still processes left?
    # slaughter them with SIGKILL
    $attempts = 5;
    while ($attempts-- > 0) {
        @pids = $self->__filter_alive(@pids);
        my $count = scalar @pids;
        last if ($count <= 0);
        printf("Killing un-cooperative %s (SIGKILL)%s\n", $arg->label, $total > 1 ? ", $count remaining..." : '')
            unless $arg->silent;
        kill(9, $_) for @pids;
        sleep 1;
    }
}

# Take an array ref, array containing process IDs
# Check which processes are still alive and return them in an array
sub __filter_alive ($self, @pids) {
    return grep { kill(0, $_) != 0 } @pids;
}

=head2 slurp_if_exists

Return the contents of the given file as a string. Trailing spaces are removed.

If the file does not exist an C<undef> value is returned. In case of other
errors (e.g. unreadable file) an error is thrown.

B<Parameters>

=over

=item * C<$file> I<Str> - file path

=back

=cut
signature_for slurp_if_exists => (
    method => 1,
    positional => [ 'Str' ],
);
sub slurp_if_exists ($self, $file) {
    return unless -e $file;

    my $content = do {
        local $INPUT_RECORD_SEPARATOR;
        my $fh;
        open $fh, '<', $file or die "Unable to open $file: $!";
        <$fh>;
    };
    chomp $content;
    return $content;
}

=head2 fork_launcher

Fork off the server launcher code.

Tries to fork a child process (which is expected to do a second fork to launch
the actual daemon) and listens to the child's output. Errors from the child
process are printed to STDERR and other output to STDOUT.

B<Parameters>

=over

=item * C<$starter> I<CodeRef> - code that runs the daemon launcher

=back

=cut
signature_for fork_launcher => (
    method => 1,
    positional => [ 'CodeRef' ],
);
sub fork_launcher ($self, $starter) {
    my $pid;
    my $redo_count = 0;
    my $child_fh;

    FORK:
    do {
        # this open call efectively does a fork and attaches the child's
        # STDOUT to $child_fh, allowing the child to send us data.
        $pid = open($child_fh, "-|");
        if (not defined $pid) {
            # recoverable fork error
            if ($!{EAGAIN}) {
                if ($redo_count > 5) {
                    warn "Could not fork process\n";
                    return 2;
                }
                sleep 5;
                $redo_count++;
                redo FORK;
            # other fork error
            } else {
                warn "Could not fork process: $ERRNO\n";
                return 2;
            }
        }
    } until defined $pid;

    my $error_marker = '$OPENXPKICTL_CLIENT_PROCESS_ERROR$';

    # PARENT
    # child process pid is available in $pid
    if ($pid) {
        my $kid;
        # wait for child process to exit (which happens either if Net::Server's
        # launcher code exits after forking the actual daemon or if it dies)
        do {
            $kid = waitpid(-1, POSIX::WNOHANG);
            sleep 1 unless $kid > 0;
        } until $kid > 0;

        # print messages from child process
        my $msg = <$child_fh>;
        if ($msg and length $msg) {
            if ($msg =~ m/\Q$error_marker\E\s*/) {
                warn "$msg\n";
                return 2;
            } else {
                print "$msg\n";
            }
        }

        return 0;

    # CHILD
    # parent process pid is available with getppid
    } else {
        # everything printed to STDOUT here will be available to the
        # parent on its $child_fh file descriptor
        eval {
            $starter->(); # this is expected to fork again
        };
        if ($EVAL_ERROR) {
            print "$error_marker $EVAL_ERROR"; # will be sent to parent's $child_fh
        }
        close STDOUT;
        close STDERR;
        exit 0;
    }
}

1;

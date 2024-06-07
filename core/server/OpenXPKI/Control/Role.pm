package OpenXPKI::Control::Role;
use OpenXPKI -role;

requires 'getopt_params';
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
    is => 'rw',
    isa => 'ArrayRef',
    lazy => 1,
    default => sub { [] },
);

has opts => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => sub { {} },
);

signature_for stop_process => (
    method => 1,
    named => [
        name => 'Str',
        pid => 'Int',
        silent => 'Bool', { default => 0 },
    ],
);
sub stop_process ($self, $arg) {
    if (kill(0, $arg->pid) == 0) {
        printf STDERR "%s is not running under PID %s\n", $arg->name, $arg->pid;
        return 2;
    }

    my $process_group = getpgrp($arg->pid);

    say 'Stopping '.$arg->name unless $arg->silent;

    # get all PIDs which belong to the current process group
    my @pids;
    my $pt = Proc::ProcessTable->new;
    for my $process (@{$pt->table}) {
        if (getpgrp($process->pid) == $process_group) {
            push @pids, $process->pid;
        }
    }

    my $process_count;

    # try to send them SIGTERM
    my $attempts = 5;
    while ($attempts-- > 0) {
        $process_count = scalar @pids;
        last if ($process_count <= 0);
        print "Stopping gracefully, $process_count (sub)processes remaining...\n" unless $arg->silent;
        foreach my $p (@pids) {
            kill(15, $p);
        }
        sleep 2;
        @pids = $self->__filter_alive(\@pids);
    }

    # still processes left?
    # slaughter them with SIGKILL
    $attempts = 5;
    while ($attempts-- > 0) {
        $process_count = scalar @pids;
        last if ($process_count <= 0);
        print "Killing un-cooperative process the hard way, $process_count (sub)processes remaining...\n" unless $arg->silent;
        foreach my $p (@pids) {
            kill(9, $p);
        }
        sleep 1;
        @pids = $self->__filter_alive(\@pids);
    }

    @pids = $self->__filter_alive(\@pids);
    $process_count = scalar @pids;
    if ($process_count <= 0) {
        print "DONE.\n" unless $arg->silent;
        return 0;
    } else {
        print "FAILED.\n" unless $arg->silent;
        warn "Could not terminate: ".join(" ", @pids).".\n";
        return 2;
    }
}

# returns a list of PIDs that belong to a given process group
sub __get_processgroup_pids ($self, $process_group) {
    my @result;

    return @result;
}

# Take an array ref, array containing process IDs
# Check which processes are still alive and return them in an array
sub __filter_alive ($self, $pids) {
    return grep { kill(0, $_) != 0 } $pids->@*;
}

sub slurp ($self, $file) {
    my $content = do {
        local $INPUT_RECORD_SEPARATOR;
        my $fh;
        open $fh, '<', $file or return;
        <$fh>;
    };
    chomp $content;
    return $content;
}

1;

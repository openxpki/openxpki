package OpenXPKI::Control::Terminal;
use OpenXPKI -class;

# Core modules
use List::Util qw( none );

# CPAN modules
use Log::Log4perl qw( :easy :no_extra_logdie_message );

# Project modules
use OpenXPKI::Config;

with 'OpenXPKI::Control::Role';


has manager => (
    is => 'rw',
    isa => 'OpenXPKI::Server::ProcTerminal',
);


sub BUILD ($self, $args) {
    try {
        # this is EE code:
        require OpenXPKI::Server::ProcTerminal;
    }
    catch ($err) {
        # we assume it's no EE edition if file does not exist
        die "This is a feature of OpenXPKI Enterprise Edition\n"
          if $err =~ m{locate OpenXPKI/Server/ProcTerminal\.pm in \@INC};
        # unknown error otherwise
        die $err;
    }

    $ENV{OPENXPKI_CONF_PATH} = $self->config_path if $self->has_config_path;

    my $config = OpenXPKI::Config->new;

    $self->manager(
        OpenXPKI::Server::ProcTerminal->new(
            log => get_logger,
            config => $config->get_hash('system.terminal') // {},
        )
    );

    if (not scalar $self->manager->list->@*) {
        print "No internally managed terminals found in configuration node system.terminal\n";
        exit 0;
    }
}

sub getopt_params ($self, $command) {
    return ();
}

sub cmd_start ($self) {
    # start single terminal
    if (my $proc_name = $self->args->[0]) {
        $self->_assert_valid_proc_name($proc_name);
        $self->start($proc_name);

    # start all terminals
    } else {
        $self->start($_) for $self->manager->list->@*;
    }
}

sub cmd_stop ($self) {
    # stop single terminal
    if (my $proc_name = $self->args->[0]) {
        $self->_assert_valid_proc_name($proc_name);
        $self->stop($proc_name);

    # stop all terminals
    } else {
        $self->stop($_) for $self->manager->list->@*;
    }
}

sub cmd_reload ($self) {
    $self->restart;
}

sub cmd_restart ($self) {
    $self->stop;
    $self->start;
}

sub cmd_status ($self) {
    my $maxlen = 0; for ($self->manager->list->@*) { $maxlen = length if length > $maxlen };

    for my $proc_name ($self->manager->list->@*) {
        my $ctrl = $self->manager->controller($proc_name);
        my $pid = $ctrl->check_server;
        printf "%-${maxlen}s - %s\n", $proc_name, $pid ? "running ($pid)" : "stopped";
    }
}

sub start ($self, $name) {
    my $client = $self->manager->proc($name);
    $client->run;
}

sub stop ($self, $name) {
    my $ctrl = $self->manager->controller($name);
    if ($ctrl->check_server) {
        my $client = $self->manager->proc($name);
        $client->stop_server;
    }
}

sub _assert_valid_proc_name ($self, $name) {
    if (none { $_ eq $name } $self->manager->list->@*) {
        say STDERR "Unknown terminal daemon name '$name'.";
        say STDERR "Available names (system.terminal): " . join(', ', $self->manager->list->@*);
        exit 1;
    }
}

__PACKAGE__->meta->make_immutable;

__DATA__

=head1 USAGE

Control the terminal daemons (EE feature).

Per default the "start", "stop" and "restart" commands process all internally
managed terminal daemons. To start or stop only one daemon, specify its name
after the command.

E.g. to start the instance configured below system.terminal.intproc run:

    %%CONTROL_SCRIPT%% start terminal intproc

=back

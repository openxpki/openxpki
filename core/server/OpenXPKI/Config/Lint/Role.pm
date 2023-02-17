package OpenXPKI::Config::Lint::Role;
use Moose::Role;

requires 'lint';

use List::Util qw( any );

has 'config' => (
    is => 'rw',
    isa => 'Connector',
    required => 1,
);

has 'headings' => (
    is => 'ro',
    isa => 'ArrayRef',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        'add_heading' => 'push',
        'remove_heading' => 'pop',
        'heading_level' => 'count',
        'get_heading' => 'get',
        'list_headings' => 'elements',
    },
);

sub current_heading_type { (shift->get_heading(-1) // {})->{type} // '' }

has 'global_error_count' => (
    is => 'ro',
    isa => 'Num',
    traits => ['Counter'],
    init_arg => undef,
    default => 0,
    handles => {
        'inc_global_error_count' => 'inc',
    },
);

has '_subpath_errors' => (
    is => 'ro',
    isa => 'ArrayRef',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        'add_error' => 'push',
        'error_count' => 'count',
        'error_list' => 'elements',
        'clear_errors' => 'clear',
    },
);

has '_subpath_warnings' => (
    is => 'ro',
    isa => 'ArrayRef',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        'add_warning' => 'push',
        'warning_count' => 'count',
        'warning_list' => 'elements',
        'clear_warnings' => 'clear',
    },
);

has 'log' => (
    required => 0,
    lazy => 1,
    is => 'ro',
    isa => 'Object',
    default => sub { Log::Log4perl->get_logger() },
);


sub log_error {
    my $self = shift;
    my $msg = shift;
    my $subpath = shift;

    $self->add_error({ subpath => $subpath, msg => $msg });
    $self->inc_global_error_count;
}

sub log_warn {
    my $self = shift;
    my $msg = shift;
    my $subpath = shift;

    $self->add_warning({ subpath => $subpath, msg => $msg });
}

sub _get_log_msg {
    my $self = shift;
    my $log = shift;

    return sprintf '    %s%s', ($log->{subpath} ? $log->{subpath}.': ' : ''), $log->{msg};
}

sub set_heading {
    my $self = shift;
    my $type = shift or die "Heading type missing";
    my $label = shift or die "Heading label";

    # implicitely end current level if e.g. a new loop iteration (due to "next;")
    # calls set_heading() without a previous call to finish_heading()
    if ($self->current_heading_type eq $type) {
        $self->finish_heading($type);
    }
    # flush logs that might have been written before a call to set_heading()
    $self->_print_logs;

    $self->add_heading({ type => $type, label => $label });
}

sub finish_heading {
    my $self = shift;
    my $type = shift or die "Heading type missing";

    # make sure current heading hierarchy contains the given type,
    # i.e. set_heading() was called (correctly) before finish_heading().
    return unless any { $type eq $_->{type} } $self->list_headings;

    # remove all headings up to the given type
    my $last_removed = '';
    do {
        $last_removed = $self->current_heading_type;
        $self->_print_logs;
        $self->remove_heading;
    } until ($last_removed eq $type);
}

sub _print_logs {
    my $self = shift;

    return unless ($self->error_count or $self->warning_count);

    if ($self->heading_level > 0) {
        my $heading =
            join ' / ',
            map {
                sprintf "%s=%s", $self->get_heading($_)->{type}, $self->get_heading($_)->{label}
            } (0..$self->heading_level-1);
        # log heading with same log level as highest message log level
        LOG: {
            if ($self->error_count)   { $self->log->error(); $self->log->error($heading); last LOG; }
            if ($self->warning_count) { $self->log->warn(); $self->log->warn($heading);  last LOG; }
        }
    }

    $self->log->error($_) for map { $self->_get_log_msg($_) } $self->error_list;
    $self->log->warn($_)  for map { $self->_get_log_msg($_) } $self->warning_list;

    $self->clear_errors;
    $self->clear_warnings;
}

1;

__END__;

package OpenXPKI::Metrics;
use Moose;

=head1 NAME

OpenXPKI::Metrics - Context object to create metrics

=head1 DESCRIPTION

This module is meant to be invoked via C<CTX('metrics')>. It offers some
additional higher level functions to create metrics.

L<Prometheus::Tiny::Shared> is used to do the actual work of writing metrics to
disk (shared memory).

The HTTP interface that exposes the metrics to an external server (Prometheus)
is implemented in L<OpenXPKI::Metrics::Prometheus>.

I<Please note that metrics are a feature of OpenXPKI Enterprise Edition.>

=cut

# Core modules
use File::Find qw();

# CPAN modules
use Feature::Compat::Try;
use Time::HiRes qw( gettimeofday tv_interval );
use Data::UUID;

################################################################################
# Attributes
#

=head1 ATTRIBUTES

=head2 Constructor parameters

=over

=item * B<enabled> I<Bool> - whether the metrics are enabled (via config).

If this returns C<0> then L</ready> will also never return C<1>.

=cut
has enabled => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
);

=item * B<cache_dir> I<Str> - path to the cache directory for L<Prometheus::Tiny::Shared>

=cut
has cache_dir => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=item * B<cache_user> I<Str> - user to be set as owner of the cache directory

=cut
has cache_user => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=item * B<cache_group> I<Str> - group to be set as owner of the cache directory

=cut
has cache_group => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=item * B<log> L<Log::Log4perl::Logger> - logger instance

=cut
has log => (
    is => 'rw',
    isa => 'Log::Log4perl::Logger',
    required => 1,
);

=back

=head1 METHODS

=head2 ready

Returns a I<Bool> value to tell whether metrics are enabled and methods like
L</start> and L</stop> can be called.

=cut
has ready => (
    is => 'ro',
    isa => 'Bool',
    lazy => 1,
    init_arg => undef,
    default => sub {
        my $self = shift;

        return 0 unless $self->enabled;

        try {
            # optional
            require Prometheus::Tiny::Shared;
            require OpenXPKI::Metrics::Prometheus;
        }
        catch ($err) {
            if ($err =~ m{locate Prometheus/Tiny/Shared\.pm in \@INC}) {
                $self->log->error("Cannot enable 'metrics': Prometheus::Tiny::Shared not found");
                return 0;
            }
            if ($err =~ m{locate OpenXPKI/Metrics/Prometheus\.pm in \@INC}) {
                $self->log->warn("Cannot enable 'metrics': EE class OpenXPKI::Metrics::Prometheus not found");
                return 0;
            }
            die $err;
        }

        return 1;
    },
);

has _prom => (
    is => 'rw',
    isa => 'Object', # Prometheus::Tiny::Shared
    lazy => 1,
    handles => [qw( set add inc dec clear histogram_observe enum_set declare format psgi )],
    builder => '_build_prom',
);

has _uuid => (
    is => 'ro',
    isa => 'Data::UUID',
    lazy => 1,
    init_arg => undef,
    default => sub { Data::UUID->new },
);

has _current_metrics => (
    is => 'ro',
    isa => 'HashRef',
    traits => ['Hash'],
    init_arg => undef,
    default => sub { {} },
    handles => {
        'add_metric' => 'set',
        'delete_metric' => 'delete',
    }
);

sub _build_prom {
    my $self = shift;

    die('Attempt to store metrics while they are either disabled or not available. Please check via method ready() before use.') unless $self->ready;

    my $dir = $self->cache_dir;
    my $dir_exists = -e $dir;

    # metrics collector instance
    require Prometheus::Tiny::Shared;
    my $prom = Prometheus::Tiny::Shared->new(filename => $dir);

    $self->log->info("Using metrics cache dir $dir");

    # set directory permissions if we created it
    unless ($dir_exists) {
        my ($user, $uid, $group, $gid) = OpenXPKI::Util->resolve_user_group(
            $self->cache_user,
            $self->cache_group,
            'metrics server process'
        );
        File::Find::find(
            sub { chown $uid, $gid, $_ or die "Could not chown '$_': $!" },
            $dir
        );
        $self->log->info("Ownership of metrics cache dir $dir set to $user:$group");
    }

    return $prom;
}

=head2 start

    my $metric_id = CTX('metrics')->start("service_command_seconds", { command => $command });

Start a timer metric, i.e. measure a duration.

Creates an ID and associates the start timestamp with that ID.

B<Parameters>

=over

=item * C<$name> I<Str> - custom metric name

=item * C<$labels> I<HashRef> - custom labels (key-value pairs) as additional metric data. Optional, default: C<{}>

=back

B<Returns> a UUID to identify the running metric (this needs to be passed
to L</stop>).

=cut
sub start {
    my $self = shift;
    my $name = shift;
    my $labels = shift // {};

    my $id = $self->_uuid->create;
    my $time_start = [gettimeofday];

    if (not $name) {
        $name = (caller(1))[3];
        $name =~ s/^OpenXPKI::/O:/;
    }

    $self->add_metric($id => { name => $name, time_start => $time_start, labels => $labels });

    # TODO Add a check to detect and delete old "running" metrics (most likely abandoned due to exceptions)

    return $id;
}

=head2 stop

    CTX('metrics')->stop($metric_id);

Stop a timer and store the duration under the name that was given to L</start>.

B<Parameters>

=over

=item * C<$id> - ID generated by L</start>

=back

=cut
sub stop {
    my $self = shift;
    my $id = shift;

    my $metric = $self->delete_metric($id) or return;

    $self->histogram_observe(
        $metric->{name}, # metric name
        tv_interval($metric->{time_start}), # value
        $metric->{labels}, # labels
        int(sprintf('%i.%i', $metric->{time_start}->@*) * 1000), # timestamp
    );
}

=head1 METHODS FROM C<Prometheus::Tiny>

=head2 set

    CTX('metric')->set($name, $value, { labels }, [timestamp])

Set the value for the named metric. The labels hashref is optional. The timestamp (milliseconds since epoch) is optional, but requires labels to be provided to use. An empty hashref will work in the case of no labels.

Trying to set a metric to a non-numeric value will emit a warning and the metric will be set to zero.

See L<Prometheus::Tiny/set>.

=head2 add

    CTX('metric')->add($name, $amount, { labels })

Add the given amount to the already-stored value (or 0 if it doesn't exist). The labels hashref is optional.

Trying to add a non-numeric value to a metric will emit a warning and 0 will be added instead (this will still create the metric if it didn't exist, and will update timestamps etc).

See L<Prometheus::Tiny/add>.

=head2 inc

    CTX('metric')->inc($name, { labels })

A shortcut for

    CTX('metric')->add($name, 1, { labels })

See L<Prometheus::Tiny/inc>.

=head2 dec

    CTX('metric')->dec($name, { labels })

A shortcut for

    CTX('metric')->add($name, -1, { labels })

See L<Prometheus::Tiny/dec>.

=head2 clear

    CTX('metric')->clear;

Remove all stored metric values. Metric metadata (set by C<declare>) is preserved.

See L<Prometheus::Tiny/clear>.

=head2 histogram_observe

    CTX('metric')->histogram_observe($name, $value, { labels })

Record a histogram observation. The labels hashref is optional.

You should declare your metric beforehand, using the C<buckets> key to set the
buckets you want to use. If you don't, the following buckets will be used.

    [ 0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10 ]

See L<Prometheus::Tiny/histogram_observe>.

=head2 enum_set

    CTX('metric')->enum_set($name, $value, { labels }, [timestamp])

Set an enum value for the named metric. The labels hashref is optiona. The timestamp is optional.

You should declare your metric beforehand, using the C<enum> key to set the
label to use for the enum value, and the C<enum_values> key to list the
possible values for the enum.

See L<Prometheus::Tiny/enum_set>.

=head2 declare

    CTX('metric')->declare($name, help => $help, type => $type, buckets => [...])

"Declare" a metric by associating metadata with it. Valid keys are:

=over 4

=item C<help>

Text describing the metric. This will appear in the formatted output sent to Prometheus.

=item C<type>

Type of the metric, typically C<gauge> or C<counter>.

=item C<buckets>

For C<histogram> metrics, an arrayref of the buckets to use. See C<histogram_observe>.

=item C<enum>

For C<enum> metrics, the name of the label to use for the enum value. See C<enum_set>.

=item C<enum_values>

For C<enum> metrics, the possible values the enum can take. See C<enum_set>.

=back

Declaring a already-declared metric will work, but only if the metadata keys
and values match the previous call. If not, C<declare> will throw an exception.

See L<Prometheus::Tiny/declare>.

=head2 format

    my $metrics = CTX('metric')->format

Output the stored metrics, values, help text and types in the L<Prometheus exposition format|https://github.com/prometheus/docs/blob/master/content/docs/instrumenting/exposition_formats.md>.

See L<Prometheus::Tiny/format>.

=head2 psgi

See L<Prometheus::Tiny/psgi>.

=cut

__PACKAGE__->meta->make_immutable;

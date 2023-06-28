package OpenXPKI::Metrics;
use Moose;

# Core modules
use File::Find qw();

# CPAN modules
use Feature::Compat::Try;
use Log::Log4perl::MDC;
use Time::HiRes qw( gettimeofday tv_interval );
use Data::UUID;

# Project modules
use OpenXPKI::Server::Context qw( CTX );

################################################################################
# Attributes
#

=head1 Attributes

=head2 Constructor parameters

=over

=item * B<enabled> I<Bool> - whether the metrics are enabled (via config)

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

=back

=head2 Others

=over

=item * B<ready> I<Bool> - tells whether metrics are enabled and L</start> and L</stop> can be called

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
                CTX('log')->system->info("Disabling 'metrics' - Prometheus::Tiny::Shared not found");
                return 0;
            }
            if ($err =~ m{locate OpenXPKI/Metrics/Prometheus\.pm in \@INC}) {
                CTX('log')->system->info("Disabling 'metrics' - EE class OpenXPKI::Metrics::Prometheus not found");
                return 0;
            }
            die $err;
        }

        return 1;
    },
);

=back

=cut

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

    CTX('log')->system->info("Using metrics cache dir $dir");

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
        CTX('log')->system->info("Ownership of metrics cache dir $dir set to $user:$group");
    }

    return $prom;
}

sub start {
    my $self = shift;
    my $label = shift;

    my $id = $self->_uuid->create;
    my $time_start = [gettimeofday];

    if (not $label) {
        $label = (caller(1))[3];
        $label =~ s/^OpenXPKI::/O:/;
    }

    $self->add_metric($id => { label => $label, time_start => $time_start });

    # TODO Add a check to detect and delete old "running" metrics (most likely abandoned due to exceptions)

    return $id;
}

sub stop {
    my $self = shift;
    my $id = shift;

    my $metric = $self->delete_metric($id) or return;

    # CTX('log')->system->warn("Logging " . $metric->{label} . " " . $metric->{time_start}->[0]);

    # fetch non-falsy MDC values
    my %context = Log::Log4perl::MDC->get_context->%*; # copy hash
    delete $context{$_} for grep { not $context{$_} } keys %context;

    $self->set(
        $metric->{label} => tv_interval($metric->{time_start}),
        \%context,
        int(sprintf('%i.%i', $metric->{time_start}->@*) * 1000)
    );
}

__PACKAGE__->meta->make_immutable;

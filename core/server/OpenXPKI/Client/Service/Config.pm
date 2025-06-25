package OpenXPKI::Client::Service::Config;
use OpenXPKI qw( -class -typeconstraints );

extends 'Connector::Multi';

# Core modules
use File::Spec;

# Project modules
use OpenXPKI::i18n qw( set_language set_locale_prefix);
use OpenXPKI::Config::Backend;

my @allowed_targets = qw( console file none );

has 'config_dir' => (
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    default => $OpenXPKI::Defaults::CLIENT_CONFIG_DIR,
);

has '+BASECONNECTOR' => (
    is => 'rw',
    isa => 'Connector',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->backend();
    },
);

has backend => (
    is => 'rw',
    isa => 'Connector',
    init_arg => 'backend',
    lazy => 1,
    default => sub {
        my $self = shift;
        return OpenXPKI::Config::Backend->new(LOCATION => $self->config_dir);
    },
);

has credential_backend => (
    is => 'rw',
    isa => 'Bool',
    default => 0
);

has services => (
    is => 'rw',
    isa => 'ArrayRef',
    init_arg => undef,
    lazy => 1,
    default => sub { [ sort shift->get_keys('service') ] },
);

# enum with custom error message
my $type = enum(\@allowed_targets);
$type->message(sub ($val = '<undef>') {
    "\n\nInvalid log target (system.logger.target): $val\n".
    "Allowed keywords: " . join(', ', @allowed_targets) . "\n\n"
});
has system_logger_target => (
    is => 'rw',
    isa => $type,
    init_arg => undef,
    lazy => 1,
    default => sub { lc( shift->get('system.logger.target') // 'file' ) },
);

# Here we do the chain loading of a serialized/signed config
sub BUILD ($self, $args) {
    # when we are here, the BASECONNECTOR is already initialized which is
    # usually an instance of O::C::Backend. We now probe if there is a
    # node called "bootstrap" and if so we replace the current backend
    if ($self->backend()->exists('bootstrap')) {

        # this is a connector definition
        my $bootstrap = $self->backend()->get_hash('bootstrap');

        my $class = $bootstrap->{class} || 'OpenXPKI::Config::Loader';
        if ($class !~ /\A(\w+\:\:)+\w+\z/) {
            die "Invalid class name $class";
        }
        ##! 16: 'Config bootstrap ' . Dumper $bootstrap
        eval { Module::Load::load($class) }; die "Unable to bootstrap config, can not use $class: $@" if $@;

        delete $bootstrap->{class};

        my $conn = $class->new( $bootstrap );
        $self->backend( $conn );
    }

    # we initialize the checksum before injecting the code ref to avoid setting
    # $Storable::Deparse and to have the same hash with openxpkiadm
    $self->backend()->checksum();

    # If the node credential is defined on the top level we make assume
    # it contains a connector specification to create a globally available
    # node to receive passwords from
    if ($self->backend()->exists('credentials')) {
        my $conn = $self->backend();
        my $meta = $conn->get_meta('credentials');
        if ($meta->{TYPE} ne "hash" || !$conn->exists('credentials.class')) {
            warn "Found credential node but it does not look like a connector specification"
        } else {
            # There is a dragon inside! We read the connector details and
            # afterwards delete the node and write back the preinitialized
            # connector. This makes assumptions on the internal cache and might
            # also not work with other backend classes.
            $self->credential_backend(1);
            my $cc = $self->get_connector('credentials');
            $self->_init_cache();
            # as it is not allowed to change the type we need to unset it first
            $conn->set('credentials' => undef);
            # now we directly attach the connector to it
            $conn->set('credentials' => $cc);
            Log::Log4perl->get_logger('system')->info("Added credential connector");
        }
    }

    # check if the system node is present
    $self->backend()->exists('system') || die "Loaded config does not contain service node.";

}

sub checksum ($self) {
    $self->BASECONNECTOR()->_config(); # makes sure the backend is initialized
    return $self->BASECONNECTOR()->checksum();
}

# duplicated from OpenXPKI::Config
sub get_scalar_as_list ($self, $path) {
    my @values;
    my $meta = $self->get_meta( $path ) // return;

    if ($meta->{TYPE} eq 'list') {
        @values = $self->get_list( $path );
    } elsif ($meta->{TYPE} eq 'scalar') {
        my $val = ( $self->get( $path ) );
        @values = ( $val ) if defined $val;
    } else {
        $self->log->error("get_scalar_as_list got invalid node type");
    }

    return @values;
}

sub endpoint_config ($self, $service, $endpoint = undef) {
    if (!$endpoint) {
        $self->log->info("Request for service config requires endpoint");
        return;
    }

    # TODO Implement wildcard and default config
    if (!$self->exists(['service', $service, $endpoint ])) {
        $self->log->info("Requested service config (service.$service.$endpoint) does not exist");
        return;
    }

    return $self->get_wrapper([ 'service', $service, $endpoint ]);
}

=head2 log4perl_conf

Reads the logger configuration (common, Mojolicious server, service endpoints)
and returns a generated Log4perl configuration string.

The following client configuration nodes are read:

    # basic Log4perl configuration
    logger:
        # Default log level (default: WARN)
        level: DEBUG

        # Target for service logs (server always logs to "console")
        #   "file"    = (default) /var/log/openxpki-client/<service>.log
        #   "console" = journald if running as systemd unit, STDOUT otherwise
        target: console

        # Complete Log4perl config that overrides everything.
        # (either a multiline string or key:value pairs)
        config: |-
            log4perl.oneMessagePerAppender = 1
            log4perl.rootLogger = INFO, BASE
            log4perl.appender.BASE = OpenXPKI::Log4perl::Appender::Journald
            log4perl.appender.BASE.layout = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.BASE.layout.ConversionPattern = [%c{2}] %m

    # Mojolicious server log level:
    # Log4perl category openxpki.client.server
    system:
        server:
            logger:
                level: TRACE

    # Service endpoint specific log level:
    # Log4perl category openxpki.client.service.<SERVICE>.<ENDPOINT>
    service:
        <SERVICE>:
            <ENDPOINT>:
                logger:
                    level: TRACE

B<Named parameters>

=over

=item * C<current_level> - Current Log4perl leven (from C<openxpkictl>)

=back

=cut
signature_for log4perl_conf => (
    method => 1,
    named => [
        current_level => 'Str',
    ],
);
sub log4perl_conf ($self, $arg) {
    my $conf = '';
    my $conf_appenders = '';

    # Use custom Log4perl config: system.logger.config overwrites everything
    my $meta = $self->get_meta('system.logger.config');
    if ($meta) {
        if ($meta->{TYPE} eq 'scalar') {
            return $self->get('system.logger.config');
        } elsif ($meta->{TYPE} eq 'hash') {
            my $conf_hash = $self->get_hash('system.logger.config');
            return join "\n", map { sprintf "%s = %s", $_, $conf_hash->{$_} } sort keys $conf_hash->%*;
        } else {
            die "Config node system.logger.config is expected to be a string or hash. Found: " . $meta->{TYPE} . "\n";
        }
    }

    # Read options and assemble Log4perl config
    my $target = $self->system_logger_target;
    my $enabled = ($target ne 'none');

    my $root_level = $enabled
        ? $self->get('system.logger.level') // $arg->current_level // 'WARN'
        : 'OFF';

    $conf.= <<"EOF";
    log4perl.oneMessagePerAppender = 1
    log4perl.rootLogger = $root_level, Console
EOF

    if ($enabled) {
        my $server_level = $self->get('system.server.logger.level') // $root_level;
        $conf.= <<"EOF";
        log4perl.logger.connector = ERROR, Console
        log4perl.logger.openxpki.client.system.server = $server_level, Console
        log4perl.additivity.openxpki.client.system.server = 0
EOF

        # show category if services also log to console (to distinct messages)
        my $cat_server = '';
        my $cat = '';
        if ('console' eq $target) {
            $cat_server = '[%c{1}] ';
            $cat        = '[%c{2}] ';
        }

        if (OpenXPKI::Util->is_systemd) {
            # journald
            $conf_appenders.= <<"EOF";
            log4perl.appender.Console                              = OpenXPKI::Log4perl::Appender::Journald
            log4perl.appender.Console.layout                       = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.Console.layout.ConversionPattern     = ${cat_server}%m [%i{verbose}]
            log4perl.appender.ConsoleSvc                           = OpenXPKI::Log4perl::Appender::Journald
            log4perl.appender.ConsoleSvc.layout                    = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.ConsoleSvc.layout.ConversionPattern  = ${cat}%m [%i{verbose}]
EOF
        } else {
            # screen
            $conf_appenders.= <<"EOF";
            log4perl.appender.Console                             = Log::Log4perl::Appender::Screen
            log4perl.appender.Console.layout                      = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.Console.layout.ConversionPattern    = %p{3} ${cat_server}%m [%i{verbose}]%n
            log4perl.appender.ConsoleSvc                          = Log::Log4perl::Appender::Screen
            log4perl.appender.ConsoleSvc.layout                   = Log::Log4perl::Layout::PatternLayout
            log4perl.appender.ConsoleSvc.layout.ConversionPattern = %p{3} ${cat}%m [%i{verbose}]%n
EOF
        }

        for my $service ($self->services->@*) {
            my $appender = 'ConsoleSvc';

            if ('file' eq $target) {
                $appender = 'File' . ucfirst($service);
                $conf_appenders.= <<"EOF";
                log4perl.appender.$appender                          = Log::Log4perl::Appender::File
                log4perl.appender.$appender.recreate                 = 1
                log4perl.appender.$appender.recreate_check_interval  = 120
                log4perl.appender.$appender.filename                 = /var/log/openxpki-client/$service.log
                log4perl.appender.$appender.layout                   = Log::Log4perl::Layout::PatternLayout
                log4perl.appender.$appender.layout.ConversionPattern = %d %p{3} %m [%i{verbose}]%n
                log4perl.appender.$appender.syswrite                 = 1
                log4perl.appender.$appender.utf8                     = 1
EOF
            }

            $conf.= <<"EOF";
            log4perl.logger.openxpki.client.service.$service = $root_level, $appender
            log4perl.additivity.openxpki.client.service.$service = 0
EOF
            for my $endpoint (sort $self->get_keys("service.$service")) {
                if (my $level = $self->get("service.$service.$endpoint.logger.level")) {
                    $conf.= <<"EOF";
                    log4perl.logger.openxpki.client.service.$service.$endpoint = $level, $appender
                    log4perl.additivity.openxpki.client.service.$service.$endpoint = 0
EOF
                }
            }
        }
    # Logging disabled? Add dummy appender.
    } else {
        $conf_appenders.= <<"EOF";
        log4perl.appender.Console        = Log::Log4perl::Appender::Screen
        log4perl.appender.Console.layout = Log::Log4perl::Layout::NoopLayout
EOF
    }

    $conf =~ s/^\s+//gm;
    $conf_appenders =~ s/^\s+//gm;

    return "$conf\n$conf_appenders";
}

__PACKAGE__->meta->make_immutable;

__END__